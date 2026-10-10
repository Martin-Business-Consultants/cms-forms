# frozen_string_literal: true

# A choice field's options (select, radio) as a visitor picks from them. A
# field can take them from a collection (`options_collection`): its
# published entries, in the collection's order (an `order` field, then
# title), each as its title. The choices typed into the builder follow
# ("Not sure yet", say). So a new service joins the form's list the moment
# it's published, and a submission naming it is accepted.
#
#   field = {"name" => "service", "type" => "select", "options_collection" => "services",
#            "options" => [{"value" => "Not sure yet", "label" => "Not sure yet"}]}
#   FormChoices.for(field)
#   # => [{"value" => "Garden Consultation", "label" => "Garden Consultation", "slug" => "garden-consultation"}, …,
#   #     {"value" => "Not sure yet", "label" => "Not sure yet"}]
module FormChoices
  module_function

  def for(field)
    entries(field["options_collection"]) + Array(field["options"]).select { it.is_a?(Hash) }
  end

  # The fields with every choice field's options worked out, as a site
  # draws them and a submission is checked against them.
  def resolve(fields)
    Array(fields).map do |field|
      collected?(field) ? field.merge("options" => self.for(field)) : field
    end
  end

  def collected?(field)
    field.is_a?(Hash) && FormValidator::OPTIONED_TYPES.include?(field["type"]) && field["options_collection"].present?
  end

  def entries(slug)
    collection = slug.presence && Collection.find_by(slug: slug)
    return [] unless collection

    collection.entries.live.sort_by { [it.frontmatter.to_h["order"].nil? ? 1 : 0, it.frontmatter.to_h["order"].to_f, it.title.to_s] }
      .map { {"value" => it.title, "label" => it.title, "slug" => it.slug} }
  end
end
