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

  def category_tags
    @category_tags ||= Tag.where('id in (
        SELECT tag_id FROM topic_tags WHERE topic_id in (
          SELECT id from topics WHERE category_id = ?
        )
      )', self.id).pluck(:name)
  end
end

module SiteExtension
  def categories
    @categories ||= begin
      categories = Category
        .includes(:uploaded_logo, :uploaded_background)
        .secured(@guardian)
        .joins('LEFT JOIN topics t on t.id = categories.topic_id')
        .select('categories.*, t.slug topic_slug')
        .order(:position)

      categories = categories.to_a

      ## Addition
      categories = categories.map do |c|
        if c.is_place
          CivicallyPlace::Place.new(c.attributes.except("topic_slug"))
        else
          c
        end
      end
      ## End of addition

      with_children = Set.new
      categories.each do |c|
        if c.parent_category_id
          with_children << c.parent_category_id
        end
      end

      allowed_topic_create = nil
      unless @guardian.is_admin?
        allowed_topic_create_ids =
          @guardian.anonymous? ? [] : Category.topic_create_allowed(@guardian).pluck(:id)
        allowed_topic_create = Set.new(allowed_topic_create_ids)
      end

      by_id = {}

      category_user = {}
      unless @guardian.anonymous?
        category_user = Hash[*CategoryUser.where(user: @guardian.user).pluck(:category_id, :notification_level).flatten]
      end

      regular = CategoryUser.notification_levels[:regular]

      categories.each do |category|
        category.notification_level = category_user[category.id] || regular
        category.permission = CategoryGroup.permission_types[:full] if allowed_topic_create&.include?(category.id) || @guardian.is_admin?
        category.has_children = with_children.include?(category.id)
        by_id[category.id] = category
      end

      categories.reject! { |c| c.parent_category_id && !by_id[c.parent_category_id] }
      categories
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

  attributes :category_tags

  def category_tags
    object.category_tags
  end
end
