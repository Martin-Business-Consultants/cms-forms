# frozen_string_literal: true

# Google reCAPTCHA's server-side check, as TurnstileVerifier is Turnstile's:
# fails closed, and the secret is Settings › Forms' reCAPTCHA secret key.
# With reCAPTCHA v3's score, below MIN_SCORE fails too.
class RecaptchaVerifier < TurnstileVerifier
  VERIFY_URL = URI("https://www.google.com/recaptcha/api/siteverify")
  TOKEN_PARAMS = %w[g-recaptcha-response recaptcha_token].freeze
  MIN_SCORE = 0.5

  def self.from_settings
    secret = Forms.captcha_secret("recaptcha_secret_key")
    secret ? new(secret) : nil
  end

  private

  def passed?(answer)
    super && (answer["score"].nil? || answer["score"].to_f >= MIN_SCORE)
  end
end
