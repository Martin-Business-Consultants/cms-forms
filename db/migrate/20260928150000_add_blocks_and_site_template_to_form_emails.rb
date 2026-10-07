# frozen_string_literal: true

# A form email's content as blocks (FormEmail::Content), and the template the
# Astro site built from them (FormEmail::SiteTemplate): its HTML, the digest
# of the blocks it was built from, and when it arrived. The core's
# db/schema.rb has the columns too (Forms was the core's), so a database loaded
# from it already does: then there's nothing to add.
class AddBlocksAndSiteTemplateToFormEmails < ActiveRecord::Migration[8.1]
  def change
    add_column :form_emails, :blocks, :json, default: [], null: false, if_not_exists: true
    add_column :form_emails, :site_template, :text, if_not_exists: true
    add_column :form_emails, :site_template_digest, :string, if_not_exists: true
    add_column :form_emails, :site_template_received_at, :datetime, if_not_exists: true
  end
end
