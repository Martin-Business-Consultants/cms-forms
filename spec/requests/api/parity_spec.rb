# frozen_string_literal: true

require "rails_helper"

# The submissions inbox and form emails over the API: what the `cms` CLI
# parses, and the capability gates.
RSpec.describe "Forms API parity", type: :request do
  let(:admin) { create(:user) }

  def auth(capabilities = nil)
    actor = capabilities ? create(:user, admin: false, role: create(:role, permissions: capabilities)) : admin
    {"Authorization" => "Bearer #{actor.api_token.token}"}
  end

  def json = JSON.parse(response.body)

  describe "forms" do
    it "takes a field's choices from a collection" do
      fields = [{name: "service", label: "Service", type: "select", options_collection: "services"}]

      post "/api/forms", params: {form: {slug: "booking", title: "Booking", fields: fields}}, headers: auth, as: :json

      expect(response).to have_http_status(:created)
      expect(Form.find_by!(slug: "booking").fields.first).to include("options_collection" => "services")
    end
  end

  describe "submissions" do
    let!(:form) do
      Form.create!(slug: "contact", title: "Contact", status: "published",
                   fields: [{"name" => "email", "label" => "Email", "type" => "email"}])
    end

    it "lists submissions across forms, and filters to one" do
      form.submissions.create!(data: {"email" => "a@b.com"}, ip: "127.0.0.1")

      get "/api/submissions", headers: auth(["submissions:read"])
      expect(response).to have_http_status(:success)
      expect(json["total"]).to eq(1)
      expect(json["submissions"].first["preview"]).to eq("a@b.com")

      get "/api/forms/contact/submissions", headers: auth(["submissions:read"])
      expect(json["total"]).to eq(1)
    end

    it "returns the full data on show" do
      submission = form.submissions.create!(data: {"email" => "a@b.com"}, ip: "127.0.0.1")

      get "/api/submissions/#{submission.id}", headers: auth(["submissions:read"])

      expect(json["submission"]["data"]).to eq("email" => "a@b.com")
    end

    it "needs submissions:delete to delete" do
      submission = form.submissions.create!(data: {"email" => "a@b.com"}, ip: "127.0.0.1")

      delete "/api/submissions/#{submission.id}", headers: auth(["submissions:read"])
      expect(response).to have_http_status(:forbidden)

      delete "/api/submissions/#{submission.id}", headers: auth(["submissions:read", "submissions:delete"])
      expect(response).to have_http_status(:no_content)
      expect(FormSubmission.count).to eq(0)
    end

    it "exposes the form's email templates with the tokens they accept" do
      get "/api/forms/contact/emails", headers: auth(["forms:read"])

      expect(response).to have_http_status(:success)
      expect(json["emails"].map { |e| e["kind"] }).to match_array(%w[notification confirmation])
      expect(json["available_tokens"]).to include("email", "form_title", "submitted_at")
    end

    it "updates one template" do
      patch "/api/forms/contact/emails/notification",
        params: {form_email: {enabled: true, subject: "New: {{form_title}}",
                              body: "From {{email}}", recipients: "ops@example.com"}},
        headers: auth(["forms:read", "forms:write"]), as: :json

      expect(response).to have_http_status(:success)
      expect(json["email"]["subject"]).to eq("New: {{form_title}}")
      expect(form.emails.find_by(kind: "notification").enabled).to be(true)
    end
  end
end
