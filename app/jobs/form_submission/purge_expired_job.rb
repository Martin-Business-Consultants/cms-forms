# frozen_string_literal: true

# Each night: submissions older than Settings › Forms › Keep submissions for,
# deleted with their files (FormSubmission::PersonalData).
class FormSubmission::PurgeExpiredJob < ApplicationJob
  queue_as :default

  def perform = FormSubmission.purge_expired
end
