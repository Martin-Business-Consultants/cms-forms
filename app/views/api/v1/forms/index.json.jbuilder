# frozen_string_literal: true

json.data @forms, partial: "api/v1/forms/form", as: :form
json.meta({total: @forms.size})
