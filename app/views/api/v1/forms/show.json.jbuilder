# frozen_string_literal: true

json.data { json.partial! "api/v1/forms/form", form: @form }
json.meta({})
