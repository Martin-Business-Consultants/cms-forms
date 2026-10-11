# frozen_string_literal: true

require "rails_helper"

RSpec.describe "API form submissions", type: :request do
  let!(:form) do
    Form.create!(slug: "contact", title: "Contact", status: "published",
                 fields: [{"name" => "email", "label" => "Email", "type" => "email"}])
  end

  let(:path) { "/api/forms/contact/submissions" }

  def turnstile_answer(success:, codes: [])
    Net::HTTPOK.new("1.1", "200", "OK").tap { |res|
      allow(res).to receive(:body).and_return(JSON.generate({"success" => success, "error-codes" => codes}))
    }
  end

  # Captures the request sent to Cloudflare and answers with `answer`.
  def stub_turnstile(answer)
    sent = {}
    http = instance_double(Net::HTTP)
    allow(http).to receive(:request) { |req| sent[:request] = req; answer }
    allow(Net::HTTP).to receive(:start) { |host, *_args, **_opts, &blk|
      sent[:host] = host
      blk.call(http)
    }
    sent
  end

  context "with no Turnstile secret configured" do
    it "accepts a submission without any captcha token" do
      expect(Net::HTTP).not_to receive(:start)

      expect {
        post path, params: {email: "a@b.com"}
      }.to change(FormSubmission, :count).by(1)
      expect(response).to have_http_status(:created)
    end
  end

  # A stranger's post can't fill the disk: one file unless the field takes
  # several, and at most FormValidator::MAX_FILES_PER_FIELD then.
  it "takes one file for a single-file field, and a capped number for a multiple one" do
    form.update!(fields: form.fields + [{"name" => "photo", "label" => "Photo", "type" => "file"},
      {"name" => "plans", "label" => "Plans", "type" => "file", "multiple" => true}])
    file = -> { Rack::Test::UploadedFile.new(StringIO.new("x"), "text/plain", original_filename: "x.txt") }

    expect { post path, params: {email: "a@b.com", photo: [file.(), file.()]} }.not_to change(FormSubmission, :count)
    expect(response.parsed_body.dig("errors", "photo")).to include("takes one file")

    expect { post path, params: {email: "a@b.com", plans: Array.new(11) { file.() }} }.not_to change(FormSubmission, :count)
    expect { post path, params: {email: "a@b.com", plans: [file.(), file.()]} }.to change(FormSubmission, :count).by(1)
  end

  # Choosing reCAPTCHA used to check nothing: every submission passed.
  context "with reCAPTCHA chosen and its secret set" do
    before do
      Setting.set("forms_settings", {"captcha_provider" => "recaptcha", "recaptcha_site_key" => "6Lc-site"})
      Setting.set_secret("forms_settings", recaptcha_secret_key: "re-sekret")
    end

    it "rejects a submission with no token" do
      expect { post path, params: {email: "a@b.com"} }.not_to change(FormSubmission, :count)
      expect(response.parsed_body).to eq({"error" => "captcha_failed"})
    end

    it "verifies the g-recaptcha-response token with Google, and fails a low v3 score" do
      sent = stub_turnstile(turnstile_answer(success: true))
      expect {
        post path, params: {:email => "a@b.com", "g-recaptcha-response" => "re-tok"}
      }.to change(FormSubmission, :count).by(1)
      expect(sent[:host]).to eq("www.google.com")
      expect(URI.decode_www_form(sent[:request].body).to_h).to include("secret" => "re-sekret", "response" => "re-tok")

      low = Net::HTTPOK.new("1.1", "200", "OK").tap { |res| allow(res).to receive(:body).and_return(JSON.generate({"success" => true, "score" => 0.1})) }
      stub_turnstile(low)
      expect { post path, params: {:email => "b@b.com", "g-recaptcha-response" => "re-tok"} }.not_to change(FormSubmission, :count)
    end
  end

  context "with a Turnstile secret configured" do
    before do
      Setting.set("forms_settings", {"captcha_provider" => "turnstile", "turnstile_secret_key" => "sekret"})
    end

    it "rejects a submission with no token" do
      expect(Net::HTTP).not_to receive(:start)

      expect {
        post path, params: {email: "a@b.com"}
      }.not_to change(FormSubmission, :count)
      expect(response).to have_http_status(:unprocessable_entity)
      expect(response.parsed_body).to eq({"error" => "captcha_failed"})
    end

    it "verifies the cf-turnstile-response token with Cloudflare, passing remoteip" do
      sent = stub_turnstile(turnstile_answer(success: true))

      expect {
        post path, params: {:email => "a@b.com", "cf-turnstile-response" => "tok-1"},
                   headers: {"REMOTE_ADDR" => "203.0.113.7"}
      }.to change(FormSubmission, :count).by(1)
      expect(response).to have_http_status(:created)

      expect(sent[:host]).to eq("challenges.cloudflare.com")
      expect(sent[:request].path).to eq("/turnstile/v0/siteverify")
      expect(URI.decode_www_form(sent[:request].body).to_h)
        .to eq({"secret" => "sekret", "response" => "tok-1", "remoteip" => "203.0.113.7"})
    end

    it "accepts the token as turnstile_token too" do
      sent = stub_turnstile(turnstile_answer(success: true))

      post path, params: {email: "a@b.com", turnstile_token: "tok-2"}

      expect(response).to have_http_status(:created)
      expect(URI.decode_www_form(sent[:request].body).to_h["response"]).to eq("tok-2")
    end

    it "rejects a token Cloudflare says is invalid" do
      stub_turnstile(turnstile_answer(success: false))

      expect {
        post path, params: {:email => "a@b.com", "cf-turnstile-response" => "bad"}
      }.not_to change(FormSubmission, :count)
      expect(response).to have_http_status(:unprocessable_entity)
      expect(response.parsed_body).to eq({"error" => "captcha_failed"})
    end

    it "logs why Cloudflare turned a token away" do
      stub_turnstile(turnstile_answer(success: false, codes: ["invalid-input-secret"]))
      allow(Rails.logger).to receive(:warn)

      post path, params: {:email => "a@b.com", "cf-turnstile-response" => "tok"}

      expect(response.parsed_body).to eq({"error" => "captcha_failed"})
      expect(Rails.logger).to have_received(:warn).with("[forms] TurnstileVerifier turned the token away: invalid-input-secret")
    end

    it "tells a secret Cloudflare knows from one it doesn't" do
      verifier = TurnstileVerifier.new("sekret")

      stub_turnstile(turnstile_answer(success: false, codes: ["invalid-input-response"]))
      expect(verifier.secret_recognised?).to be(true)

      stub_turnstile(turnstile_answer(success: false, codes: ["invalid-input-secret"]))
      expect(verifier.secret_recognised?).to be(false)

      allow(Net::HTTP).to receive(:start).and_raise(Net::OpenTimeout)
      expect(verifier.secret_recognised?).to be_nil
    end

    it "fails closed when Cloudflare can't be reached" do
      allow(Net::HTTP).to receive(:start).and_raise(Net::OpenTimeout)

      post path, params: {:email => "a@b.com", "cf-turnstile-response" => "tok"}

      expect(response).to have_http_status(:unprocessable_entity)
      expect(response.parsed_body).to eq({"error" => "captcha_failed"})
    end

    it "still short-circuits on the honeypot before checking the captcha" do
      expect(Net::HTTP).not_to receive(:start)

      expect {
        post path, params: {:email => "a@b.com", Form::HONEYPOT_FIELD => "bot"}
      }.not_to change(FormSubmission, :count)
      expect(response).to have_http_status(:created)
    end

    it "skips verification when another captcha provider is selected" do
      Setting.set("forms_settings", {"captcha_provider" => "none"})
      expect(Net::HTTP).not_to receive(:start)

      post path, params: {email: "a@b.com"}

      expect(response).to have_http_status(:created)
    end
  end
end
