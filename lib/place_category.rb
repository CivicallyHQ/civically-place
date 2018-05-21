require_dependency 'category'
class ::Category
  def create_category_definition
    nil
  end

  def is_place
    ActiveModel::Type::Boolean.new.cast(self.custom_fields['is_place'])
  end

  def parent_category_validator
    if parent_category_id
      errors.add(:base, I18n.t("category.errors.self_parent")) if parent_category_id == id
      errors.add(:base, I18n.t("category.errors.uncategorized_parent")) if uncategorized?
    end
  end
end

module SiteExtension
  def categories
    super.map do |c|
      if c.is_place
        CivicallyPlace::Place.new(c.attributes.except("topic_slug"))
      else
        c
      end
    end
  end
end

class ::Site
  prepend SiteExtension
end

SERIALIZED_PLACE_ATTRIBUTES = [
  :place_name,
  :place_active,
  :place_type,
  :place_id,
  :can_join,
  :user_count,
  :user_count_min
]

module CategorySerializerPlaceExtension
  def attributes(*args)
    attrs = super
    SERIALIZED_PLACE_ATTRIBUTES.each do |a|
      attrs[a] = object.send(a) if object.respond_to?(a)
    end
    attrs
  end
end

class ::BasicCategorySerializer
  prepend CategorySerializerPlaceExtension
end
