# frozen_string_literal: true

# A person's submissions, found by their email address in any field, for an
# access request (download them) or an erasure request (delete them, files
# too) — Submissions › Personal data. And the retention Settings › Forms sets:
# submissions older than it are deleted each night (PurgeExpiredJob).
module FormSubmission::PersonalData
  extend ActiveSupport::Concern

  # Settings › Forms › Keep submissions for: days, or nil for always.
  RETENTION_CHOICES = {"" => "Always", "30" => "30 days", "90" => "90 days", "180" => "6 months",
                       "365" => "1 year", "730" => "2 years"}.freeze

  class_methods do
    # Every submission with `email` as a whole value in any field, any case.
    def holding_email(email)
      address = email.to_s.strip.downcase
      return none unless address.match?(URI::MailTo::EMAIL_REGEXP)

      candidates = where("LOWER(CAST(data AS TEXT)) LIKE ?", "%#{sanitize_sql_like(address)}%").includes(:form)
      where(id: candidates.select { it.email_values.include?(address) }.map(&:id))
    end

    def retention_days
      days = Setting.get(Forms::SETTING_KEY)["retention_days"].to_i
      days.positive? ? days : nil
    end

    # Deletes what's older than the retention, with its files; the count.
    def purge_expired(now: Time.current)
      days = retention_days or return 0
      expired = where(created_at: ...(now - days.days))
      count = 0
      expired.find_each { it.destroy!; count += 1 }
      track_event(:expired_deleted, count: count, retention_days: days) if count.positive?
      count
    end

    # A fingerprint for the audit log: which request it was, not who.
    def email_fingerprint(email) = OpenSSL::Digest::SHA256.hexdigest(email.to_s.strip.downcase)[0, 12]
  end

  # Every value in it that's an email address, down-cased.
  def email_values
    Array(data&.values).flatten.filter_map { it.to_s.strip.downcase if it.to_s.strip.match?(URI::MailTo::EMAIL_REGEXP) }
  end

  # What the person submitted, for their download.
  def personal_export
    {form: form&.title, submitted_at: created_at.iso8601, answers: data,
     files: files.map { {filename: it.filename.to_s, content_type: it.content_type, byte_size: it.byte_size} }}
  end
end
