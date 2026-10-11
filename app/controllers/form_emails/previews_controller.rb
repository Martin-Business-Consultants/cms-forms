# frozen_string_literal: true

# The email editor's preview: the email as the editor has it now (saved or
# not), sent to nobody, drawn for a made-up submission (FormEmail::Sample)
# into the preview sheet's frame. Nothing is saved.
class FormEmails::PreviewsController < ApplicationController
  include PluginGated
  include FormEmails::Editing
  plugin :forms

  requires_capability "forms:write", only: [:create, :update]

  def create
    email = @form.emails.find_by!(kind: params[:email_kind])
    email.assign_attributes(email_attributes(email))
    message = FormSubmissionMailer.with(form_email: email, submission: FormEmail::Sample.submission(@form),
      recipients: ["preview@example.com"]).deliver

    render html: browser_html(message).html_safe, layout: false
  end

  # The editor's form carries _method=patch; a preview is the same either way.
  alias_method :update, :create

  private

  # The message's HTML with what it carries inline (the logo, cid:) as data:
  # URIs, which a browser can draw.
  def browser_html(message)
    html = (message.html_part || message).body.decoded
    message.attachments.select(&:inline?).reduce(html) do |drawn, attachment|
      drawn.gsub("cid:#{attachment.content_id.to_s.delete("<>")}",
        "data:#{attachment.mime_type};base64,#{Base64.strict_encode64(attachment.decoded)}")
    end
  end
end
