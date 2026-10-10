# frozen_string_literal: true

# A published form as a site renders and posts it: a choice field taking its
# choices from a collection carries them, worked out (FormChoices).
json.extract! form, :id, :slug, :title, :submit_label, :success_message
json.fields FormChoices.resolve(form.fields)
json.action form.submit_url.presence || api_form_submissions_url(form.slug, **Site.url_options)
json.honeypot Form::HONEYPOT_FIELD
json.captcha Forms.public_captcha
json.updated_at form.updated_at
