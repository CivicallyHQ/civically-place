require_dependency 'category'
class ::Category
  def create_category_definition
    nil
  end

  def is_place
    ActiveModel::Type::Boolean.new.cast(self.custom_fields['is_place'])
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
  :can_join,
  :user_count,
  :user_count_min,
  :moderator_election_url
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

require_dependency 'guardian/topic_guardian'
module ::TopicGuardian
  ## You can only create topics in your place or your country
  def can_create_topic_on_category?(category)
    is_admin? ||
    (can_create_topic?(nil) &&
      category &&
      ## user meets category permissions
      Category.topic_create_allowed(self).where(id: category.id).count == 1 &&
      ## is user's place
      ((category.is_place && (category.id === user.place_category_id ||
      ## or user's country
      CivicallyPlace::Place.is_home_country(category.id, user))) ||
      ## or is a meta category
      category.meta))
  end
end
