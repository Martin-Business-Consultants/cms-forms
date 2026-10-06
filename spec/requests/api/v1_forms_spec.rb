# frozen_string_literal: true

require "rails_helper"

# The delivery API's forms: what a site needs to render a form and post it
# straight to the CMS, Turnstile included.
RSpec.describe "Delivery API v1: forms", type: :request do
  let(:admin) { create(:user) }
  let(:token) { {"Authorization" => "Bearer #{admin.api_token.token}"} }

  def json = JSON.parse(response.body)

  before do
    switch_plugin :forms, on: true
    Form.create!(slug: "contact", title: "Contact", status: "published", fields: [{"name" => "email", "label" => "Email", "type" => "email"}])
    Form.create!(slug: "draft", title: "Draft", status: "draft", fields: [])
  end

  it "lists the published forms with where to post, the honeypot and the captcha's public key" do
    Setting.set("forms_settings", captcha_provider: "turnstile", turnstile_site_key: "0x4AAA")
    Setting.set_secret("forms_settings", turnstile_secret_key: "0x4SECRET")

    get "/api/v1/forms", headers: token

    form = json["data"].sole
    expect(form).to include("slug" => "contact", "honeypot" => "_hp",
      "action" => "http://example.com/api/forms/contact/submissions",
      "captcha" => {"provider" => "turnstile", "site_key" => "0x4AAA"})
    expect(response.body).not_to include("0x4SECRET")

    get "/api/v1/site", headers: token
    expect(json.dig("data", "plugin_config", "forms", "captcha", "site_key")).to eq("0x4AAA")
  end

  it "has no captcha until both its keys are set, and hides drafts" do
    get "/api/v1/forms/contact", headers: token
    expect(json.dig("data", "captcha")).to be_nil

    get "/api/v1/forms/draft", headers: token
    expect(response).to have_http_status(:not_found)
  end
end
