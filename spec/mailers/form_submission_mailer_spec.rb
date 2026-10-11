# frozen_string_literal: true

require "rails_helper"

RSpec.describe FormSubmissionMailer do
  let(:form) do
    Form.create!(slug: "contact", title: "Contact", status: "published",
      fields: [{"name" => "email", "label" => "Email", "type" => "email", "required" => true}])
  end
  let(:submission) { form.submissions.create!(data: {"email" => "al@b.test"}, meta: {}, ip: "1.2.3.4") }

  def sent
    described_class.with(form_email: form.notification_email, submission: submission, recipients: ["ops@x.test"]).deliver
  end

  def html(mail = sent) = (mail.html_part || mail).body.decoded

  def logo!
    logo = Asset.create!(folder: "/", file: {io: StringIO.new("PNG"), filename: "logo.png", content_type: "image/png"})
    Setting.set("branding", {"logo_id" => logo.id.to_s})
  end

  # Inline (cid:), so it shows in a mail client that won't fetch remote
  # images; never a link to the public website, which doesn't serve it.
  it "carries the branding logo inline" do
    logo!
    Setting.set("general", {"site_base_url" => "https://www.acme.test"})

    mail = sent
    expect(html(mail).scan("<img").size).to eq(1)
    expect(html(mail)).to include(%(<img src="cid:logo@cms"))
    expect(mail.attachments.sole).to be_inline
    expect(html(mail)).not_to include("acme.test/rails")
  end

  it "leaves the logo out when Branding has none" do
    expect(html).not_to include("<img")
  end

  describe "in the site's design" do
    let(:template) { %(<table><tr><td data-cms-logo><img alt="Acme"></td></tr><tr data-cms-repeat="answers"><td>{{answer.label}}</td></tr></table>) }

    before do
      email = form.notification_email
      email.receive_site_template!(html: template, digest: email.content_digest)
    end

    it "puts the logo where the template marks it" do
      logo!
      mail = sent

      expect(html(mail)).to include(%(<img alt="Acme" src="cid:logo@cms">))
      expect(html(mail)).not_to include("data-cms-logo")
      expect(mail.attachments.sole).to be_inline
    end

    it "takes the place out, and attaches nothing, without a logo" do
      mail = sent

      expect(html(mail)).not_to include("<img", "data-cms-logo")
      expect(mail.attachments).to be_empty
    end
  end
end
