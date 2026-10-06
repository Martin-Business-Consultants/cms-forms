# A published form as a site renders and posts it.
json.extract! form, :id, :slug, :title, :fields, :submit_label, :success_message
json.action form.submit_url.presence || api_form_submissions_url(form.slug, **Site.url_options)
json.honeypot Form::HONEYPOT_FIELD
json.captcha Forms.public_captcha
json.updated_at form.updated_at
