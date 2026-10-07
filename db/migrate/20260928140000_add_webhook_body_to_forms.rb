# frozen_string_literal: true

# What a form's own webhook posts: every field (the default, as before), or
# only the keys it maps to a field's value or a custom value (FormWebhookBody).
# The core's db/schema.rb has the column too (Forms was the core's), so a
# database loaded from it already does: then there's nothing to add.
class AddWebhookBodyToForms < ActiveRecord::Migration[8.1]
  def change
    add_column :forms, :webhook_body, :json, default: {}, null: false, if_not_exists: true
  end
end
