# frozen_string_literal: true

require "rails_helper"

# What the site holds about someone: found by their address, downloaded or
# deleted on request; and submissions kept only as long as Settings › Forms
# says.
RSpec.describe "Personal data in submissions", type: :request do
  let(:admin) { create(:user) }
  let(:form) do
    Form.create!(slug: "contact", title: "Contact", status: "published",
      fields: [{"name" => "email", "label" => "Email", "type" => "email"}, {"name" => "message", "label" => "Message", "type" => "textarea"}])
  end

  def submit(data, at: Time.current) = form.submissions.create!(data: data, meta: {}, ip: "1.2.3.4", created_at: at)

  before { sign_in_as admin }

  it "finds someone's submissions by their address, any case, and only theirs" do
    mine = submit({"email" => "Ann@Example.com", "message" => "Hi"})
    submit({"email" => "bob@example.com", "message" => "ann@example.com is my friend"})

    get submissions_personal_data_path(email: "ann@example.com")
    expect(response.body).to include("1 submission hold")

    get export_submissions_personal_data_path(email: "ann@example.com")
    expect(response.media_type).to eq("application/json")
    expect(JSON.parse(response.body)["submissions"].sole["answers"]).to eq(mine.data)
  end

  it "deletes them on request, recording how many but not who" do
    submit({"email" => "ann@example.com", "message" => "Hi"})
    submit({"email" => "ann@example.com", "message" => "Again"})
    other = submit({"email" => "bob@example.com", "message" => "Hello"})

    delete submissions_personal_data_path, params: {email: "ann@example.com"}

    expect(FormSubmission.pluck(:id)).to eq([other.id])
    event = AuditLog.where(action: "submission.personal_data_deleted").last
    expect(event.metadata["count"]).to eq(2)
    expect(event.metadata.to_json).not_to include("ann@example.com")
  end

  it "keeps submissions only as long as Settings › Forms says, each night" do
    old = submit({"email" => "a@b.test"}, at: 100.days.ago)
    recent = submit({"email" => "c@d.test"}, at: 10.days.ago)

    expect(FormSubmission.purge_expired).to eq(0)

    patch settings_forms_path, params: {settings: {retention_days: "90"}}
    expect(FormSubmission.purge_expired).to eq(1)
    expect(FormSubmission.exists?(old.id)).to be(false)
    expect(FormSubmission.exists?(recent.id)).to be(true)
  end
end
