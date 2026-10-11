# frozen_string_literal: true

require "forms/engine"

# Forms: the forms a site renders (Form, its fields and two emails), the
# public endpoint they post to, and the Submissions inbox. Installed from its own
# repository (docs/plugins.md in the core) and on by default.
#
# Its models keep the names and tables they had in the core (forms,
# form_submissions, form_emails) — they predate plugins; a new table would be
# prefixed.
module Forms
  # Sender and spam-protection settings (Settings › Forms).
  SETTING_KEY = "forms_settings"

  # The spam protection a site shows on its forms: the provider, its public
  # site key and how the widget is drawn ({provider: "turnstile",
  # site_key: "0x4…", theme: "auto"}; theme is auto, light or dark), or nil
  # when none is set up with both its keys. Never the secret.
  def self.public_captcha
    settings = Setting.get(SETTING_KEY)
    provider = settings["captcha_provider"].presence_in(%w[turnstile recaptcha]) or return nil
    site_key = settings["#{provider}_site_key"].presence
    return unless site_key && captcha_secret("#{provider}_secret_key").present?

    {provider: provider, site_key: site_key, theme: settings["captcha_theme"].presence_in(%w[light dark]) || "auto"}
  end

  # A captcha secret key: from the setting's encrypted `secrets`, or the plain
  # value an install saved before they were encrypted (the
  # EncryptFormCaptchaSecrets migration moves those).

  def self.captcha_secret(name)
    Setting.secret(SETTING_KEY, name) || Setting.get(SETTING_KEY)[name.to_s].to_s.strip.presence
  end
end
