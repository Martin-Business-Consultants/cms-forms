# frozen_string_literal: true

# Submissions › Personal data: someone asks what the site holds about them,
# or to have it deleted. Their email address finds every submission holding
# it; they can be downloaded (submissions:read) or deleted with their files
# (submissions:delete). The audit log keeps the count and a fingerprint of
# the address, never the address.
class Submissions::PersonalDataController < ApplicationController
  include PluginGated
  plugin :forms

  requires_capability "submissions:read", only: [:show, :export]
  requires_capability "submissions:delete", only: :destroy

  def show
    @email = params[:email].to_s.strip
    @submissions = @email.present? ? FormSubmission.holding_email(@email).order(created_at: :desc).to_a : []
  end

  def export
    submissions = FormSubmission.holding_email(params[:email]).order(:created_at).to_a
    FormSubmission.track_event(:personal_data_exported, count: submissions.size, email: FormSubmission.email_fingerprint(params[:email]))
    send_data JSON.pretty_generate({email: params[:email].to_s.strip, exported_at: Time.current.iso8601,
      submissions: submissions.map(&:personal_export)}), filename: "personal-data.json", type: "application/json", disposition: "attachment"
  end

  def destroy
    deleted = FormSubmission.holding_email(params[:email]).destroy_all
    FormSubmission.track_event(:personal_data_deleted, count: deleted.size, email: FormSubmission.email_fingerprint(params[:email]))
    redirect_to submissions_personal_data_path, notice: "Deleted #{helpers.pluralize(deleted.size, "submission")} and their files."
  end
end
