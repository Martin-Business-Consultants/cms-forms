# frozen_string_literal: true

require "rails_helper"

RSpec.describe FormEmail::Sample do
  it "answers a first and a last name as parts of one name, so they read once side by side" do
    form = Form.new(slug: "contact", title: "Contact", fields: [
      {"name" => "first_name", "label" => "First name", "type" => "text"},
      {"name" => "last_name", "label" => "Last name", "type" => "text"},
      {"name" => "name", "label" => "Your name", "type" => "text"},
      {"name" => "company", "label" => "Company", "type" => "text"}
    ])
    submission = described_class.submission(form)

    expect(FormTokens.render(form, "{{first_name}} {{last_name}}", submission)).to eq("Sam Sample")
    expect(submission.data).to include("name" => "Sam Sample", "company" => "Sample company")
  end
end
