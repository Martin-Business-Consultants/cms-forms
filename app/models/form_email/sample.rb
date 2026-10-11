# frozen_string_literal: true

# A made-up submission to a form, for the email editor's preview and test
# send: a plausible answer for each field, never saved.
module FormEmail::Sample
  module_function

  def submission(form)
    data = Array(form.fields).select { it.is_a?(Hash) && it["name"].present? }.to_h do |field|
      [field["name"], answer(field)]
    end
    FormSubmission.new(form: form, data: data.compact, meta: {}, ip: "203.0.113.7", created_at: Time.current, id: 1234)
  end

  def answer(field)
    choices = FormChoices.for(field).filter_map { it["label"] }
    case field["type"]
    when "email" then "sam@example.com"
    when "tel" then "555 0100"
    when "url" then "https://example.com"
    when "textarea" then "A longer answer, as someone might write it."
    when "select", "radio" then choices.first
    when "checkbox" then "Yes"
    when "file" then nil
    else name_answer(field["name"].to_s) || "Sample #{(field["label"].presence || field["name"]).to_s.downcase}"
    end
  end

  # A name field's part of "Sam Sample": a first name and a last name, set
  # side by side ({{first_name}} {{last_name}}), read as one name, not twice.
  def name_answer(name)
    key = name.downcase
    return unless key.include?("name")

    if key.match?(/first|given|fore/) then "Sam"
    elsif key.match?(/last|family|sur/) then "Sample"
    elsif key.match?(/middle/) then "J."
    else "Sam Sample"
    end
  end
end
