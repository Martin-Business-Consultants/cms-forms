# frozen_string_literal: true

require "rails_helper"

RSpec.describe FormSubmissionMailer do
  let(:form) do
    Form.create!(slug: "contact", title: "Contact", status: "published",
      fields: [{"name" => "email", "label" => "Email", "type" => "email", "required" => true}])
  end
  let(:submission) { form.submissions.create!(data: {"email" => "al@b.test"}, meta: {}, ip: "1.2.3.4") }

  def html
    described_class.with(form_email: form.notification_email, submission: submission, recipients: ["ops@x.test"])
      .deliver.body.decoded
  end

  # The logo is a CMS file, so it's linked on the CMS (APP_HOST, example.com
  # in tests). The public website (Settings › General) doesn't serve it.
  it "links the branding logo on the CMS itself, not the public site" do
    logo = Asset.create!(folder: "/", file: {io: StringIO.new("PNG"), filename: "logo.png", content_type: "image/png"})
    Setting.set("branding", {"logo_id" => logo.id.to_s})
    Setting.set("general", {"site_base_url" => "https://www.acme.test"})

    expect(html).to match(%r{<img src="http://example\.com/rails/active_storage/blobs/redirect/[^"]+/logo\.png"})
    expect(html).not_to include("acme.test/rails")
  end

  it "leaves the logo out when Branding has none" do
    expect(html).not_to include("<img")
  end
end
