# frozen_string_literal: true

# GET /api/v1/forms and /api/v1/forms/<slug> — the published forms, as a site
# renders them: their fields, where the browser posts (`action`, on the CMS),
# the honeypot field to leave empty, and the spam protection to show
# (`captcha`: the provider and its site key; the secret stays here). The
# delivery API's shape (Api::V1::BaseController).
class Api::V1::FormsController < Api::V1::BaseController
  include PluginGated
  plugin :forms

  requires_capability "forms:read", only: [:index, :show]

  def index
    @forms = Form.where(status: "published").order(:slug).to_a
    cache_tags("forms", @forms.map { "form:#{it.slug}" })
  end

  def show
    @form = Form.where(status: "published").find_by!(slug: params[:slug])
    cache_tags("form:#{@form.slug}")
  end
end
