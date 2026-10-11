# frozen_string_literal: true

# What the email editor posts, read back: its settings, and its blocks
# through ContentForm against FormEmail::BlockTypes.
module FormEmails::Editing
  extend ActiveSupport::Concern

  included do
    before_action { @form = Form.find_by!(slug: params[:form_slug]) }
  end

  private

  def email_attributes(email)
    attributes = params.require(:form_email).permit(:enabled, :subject, :from_field, :recipients, recipient_entries: [:name, :email]).to_h
    # The editor's Name and Email rows, as the address list `recipients` holds.
    if attributes.key?("recipient_entries")
      rows = attributes.delete("recipient_entries")
      attributes["recipients"] = FormEmail.new.tap { it.recipient_entries = rows.is_a?(Hash) ? rows.values : rows }.recipients
    end
    raw = params.dig(:form_email, :blocks)
    attributes["blocks"] = ContentForm.blocks(raw, block_types: FormEmail::BlockTypes.by_slug) unless raw.nil?
    attributes
  end
end
