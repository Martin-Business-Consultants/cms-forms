# frozen_string_literal: true

require "rails_helper"

# What Forms adds to core screens: Site Health's spam check, webhooks narrowed
# to forms, and the audit trail of a bulk delete.
RSpec.describe "Forms in the core", type: :request do
  let(:admin) { create(:user) }

  def last_event = AuditLog.order(:id).last

  before { switch_plugin :forms, on: true }

  it "counts spam protection only with the provider's both keys" do
    Form.create!(slug: "contact", title: "Contact", status: "published", fields: [{"name" => "email", "label" => "Email", "type" => "email"}])
    Setting.set("forms_settings", captcha_provider: "turnstile", turnstile_site_key: "0x4AAA")
    expect(SiteHealth.checks.find { it.key == "captcha" }.ok).to be(false)

    Setting.set_secret("forms_settings", turnstile_secret_key: "0x4BBB")
    expect(SiteHealth.checks.find { it.key == "captcha" }.ok).to be(true)
  end

  it "narrows submission events to the chosen forms" do
    sign_in_as admin
    webhook = Webhook.create!(name: "n", url: "https://e.com", events: ["page.published"])

    patch webhook_url(webhook), params: {webhook: {name: "n", url: webhook.url, events: ["submission.created"],
                                                   event_filters: {"submission.created" => {form_slugs: ["contact"]}}}}
    expect(webhook.reload.event_filters).to eq("submission.created" => {"form_slugs" => ["contact"]})
  end

  it "names the forms a bulk delete found" do
    sign_in_as admin
    Form.create!(slug: "contact", title: "Contact", status: "draft", fields: [])

    post forms_bulk_deletions_path, params: {slugs: %w[contact ghost]}

    expect(last_event).to have_attributes(action: "form.bulk_deleted", metadata: {"count" => 1, "slugs" => %w[contact]})
  end
end
