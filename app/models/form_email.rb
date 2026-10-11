# frozen_string_literal: true

# A per-form email template. Two kinds, one of each per form:
#   - "notification" — fired to admin recipient(s) on each new submission
#   - "confirmation" — auto-reply to the submitter, addressed to the email
#                      stored under `from_field` in the submission data
#
# Subject and body support {{field_name}} placeholder substitution against
# the submission's data hash, plus a few special tokens: {{form_title}},
# {{submission_id}}, {{submitted_at}}, {{ip}}.
class FormEmail < ApplicationRecord
  include Eventable
  include FormEmail::Content
  include FormEmail::SiteTemplate

  KINDS = %w[notification confirmation].freeze

  belongs_to :form

  validates :kind, inclusion: {in: KINDS}
  validates :kind, uniqueness: {scope: :form_id}
  validates :subject, presence: true, if: :enabled?
  validate  :validate_recipients

  scope :enabled, -> { where(enabled: true) }

  def notification?
    kind == "notification"
  end

  def confirmation?
    kind == "confirmation"
  end

  # One of the notification's recipients: a name (blank for none) and an
  # address; as it goes in the To line, "Name" <address>.
  Recipient = Data.define(:name, :email) do
    def to_s
      return email if name.blank?

      Mail::Address.new.tap { it.address = email; it.display_name = name }.format
    end
  end

  # The notification's recipients (the email editor's Name and Email rows),
  # read from `recipients`: an address list ("Sarah" <sarah@acme.com>,
  # ops@acme.com), which plain comma- or newline-separated addresses, as it
  # held before there were names, still are.
  def recipient_entries
    text = recipients.to_s.split(/\s*\n\s*/).compact_blank.join(", ")
    return [] if text.blank?

    Mail::AddressList.new(text).addresses.map { Recipient.new(name: it.display_name.to_s, email: it.address.to_s) }
  rescue Mail::Field::ParseError
    recipients.to_s.split(/[,\n]/).map(&:strip).reject(&:empty?).map { Recipient.new(name: "", email: it) }
  end

  # [{name:, email:}, …] → `recipients`; rows without an address, and an
  # address given twice, are dropped.
  def recipient_entries=(rows)
    entries = Array(rows).filter_map do |row|
      row = row.to_h.stringify_keys
      email = row["email"].to_s.strip
      Recipient.new(name: row["name"].to_s.strip.delete('"<>'), email: email) if email.present?
    end
    self.recipients = entries.uniq { it.email.downcase }.map(&:to_s).join(", ")
  end

  # Who the notification goes to, as To addresses ("Name" <address>).
  # Only meaningful for notification rows.
  def recipient_list = recipient_entries.map(&:to_s)

  # Submitter's email for confirmation rows. Reads form data using
  # `from_field` if set, otherwise auto-detects the first field of type=email.
  def submitter_email_for(submission)
    return nil unless confirmation?

    name = from_field.presence || form.fields.find { |f| f.is_a?(Hash) && f["type"] == "email" }&.dig("name")
    return nil if name.blank?

    val = submission.data.is_a?(Hash) ? submission.data[name] : nil
    val.is_a?(String) && val.match?(URI::MailTo::EMAIL_REGEXP) ? val : nil
  end

  # Render `template` with {{token}} substitutions against the given
  # submission (FormTokens). Returns plain text — the view is responsible for
  # HTML escaping.
  def render(template, submission)
    FormTokens.render(form, template, submission)
  end

  private

  def validate_recipients
    return unless notification?
    return unless enabled?

    entries = recipient_entries
    if entries.empty?
      errors.add(:recipients, "must have at least one recipient when enabled")
    end
    entries.reject { it.email.match?(URI::MailTo::EMAIL_REGEXP) }.each do |entry|
      errors.add(:recipients, "has #{entry.email.inspect}, which isn't an email address")
    end
  end
end
