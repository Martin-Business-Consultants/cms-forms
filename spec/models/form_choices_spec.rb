# frozen_string_literal: true

require "rails_helper"

RSpec.describe FormChoices do
  let(:services) { Collection.create!(slug: "services", name: "Services", schema: {"fields" => [{"name" => "order", "label" => "Order", "type" => "integer"}]}) }
  let(:field) do
    {"name" => "service", "label" => "Service", "type" => "select", "options_collection" => "services",
     "options" => [{"value" => "Not sure yet", "label" => "Not sure yet"}]}
  end

  before do
    services.entries.create!(slug: "design", title: "Design", status: "published", locale: "en", frontmatter: {"order" => 2})
    services.entries.create!(slug: "consult", title: "Consultation", status: "published", locale: "en", frontmatter: {"order" => 1})
    services.entries.create!(slug: "secret", title: "Secret", status: "draft", locale: "en")
  end

  it "lists a collection's published entries in its order, then the typed choices" do
    expect(described_class.for(field)).to eq([
      {"value" => "Consultation", "label" => "Consultation", "slug" => "consult"},
      {"value" => "Design", "label" => "Design", "slug" => "design"},
      {"value" => "Not sure yet", "label" => "Not sure yet"}
    ])
  end

  it "holds a submission to them, a newly published entry included" do
    form = Form.create!(slug: "enquiry", title: "Enquiry", submit_label: "Send", status: "published", fields: [field])

    expect(form.validate_submission({"service" => "Design"})).to be_empty
    expect(form.validate_submission({"service" => "Secret"})).to include("service")

    services.entries.find_by!(slug: "secret").update!(status: "published")
    expect(form.validate_submission({"service" => "Secret"})).to be_empty
  end

  it "lets a choice field stand on a collection alone, and reads it back from the builder" do
    alone = field.merge("options" => [])
    expect(FormValidator.validate_fields_shape([alone])).to be_empty
    expect(FormValidator.validate_fields_shape([alone.except("options_collection")])).to include(/options must be/)

    rows = {"a" => {"name" => "service", "label" => "Service", "type" => "select", "options" => "", "options_collection" => "services"}}
    expect(FormFields.from_params(rows)).to eq([{"name" => "service", "label" => "Service", "type" => "select", "options" => [], "options_collection" => "services"}])
  end

  it "works out every choice field of a form, leaving the rest alone" do
    fields = [{"name" => "name", "label" => "Name", "type" => "text"}, field]

    resolved = described_class.resolve(fields)

    expect(resolved.first).to eq(fields.first)
    expect(resolved.last["options"].map { it["value"] }).to eq(["Consultation", "Design", "Not sure yet"])
  end
end
