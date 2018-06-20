## Currenty we use the category to store all the place data. That data is structured by the place model.

Category.register_custom_field_type('is_place', :boolean)
Category.register_custom_field_type('place_type', :string)
Category.register_custom_field_type('place_id', :integer)
Category.register_custom_field_type('can_join', :boolean)
Category.register_custom_field_type('user_count', :integer)
Category.register_custom_field_type('user_count_min', :integer)

class CivicallyPlace::Place < Category
  self.table_name = "categories"

  def place_type
    if self.custom_fields['place_type']
      self.custom_fields['place_type']
    else
      nil
    end
  end

  def place_name
    self.name
  end

  def place_id
    if is_country
      nil
    else
      self.custom_fields['place_id'].to_i
    end
  end

  def can_join
    ActiveModel::Type::Boolean.new.cast(self.custom_fields['can_join'])
  end

  def user_count
    if self.custom_fields['user_count']
      self.custom_fields['user_count'].to_i
    else
      0
    end
  end

  def user_count_min
    if self.custom_fields['user_count_min']
      self.custom_fields['user_count_min'].to_i
    elsif place_type && SiteSetting.try("place_#{place_type}_user_count_min".to_sym)
      SiteSetting.send("place_#{place_type}_user_count_min").to_i
    else
      0
    end
  end

  def country
    if is_country
      self
    elsif is_town
      self.parent_category
    else
      self.parent_category
    end
  end

  def town
    if is_neighbourhood
      self.parent_category
    elsif is_town
      self
    else
      nil
    end
  end

  def is_multinational
    place_type === 'multinational'
  end

  def is_country
    place_type === 'country'
  end

  def is_town
    place_type === 'town'
  end

  def is_neighbourhood
    place_type === 'neighbourhood'
  end

  def child_categories
    @child_categories ||= Category.where(parent_category_id: id)
  end

  def country_categories
    return [] if child_categories.blank?
    child_categories.select { |c| c.is_place }
  end

  def country_categories_ids
    country_categories.map { |c| c.id }
  end

  def country_categories_active
    return [] if country_categories.blank?
    country_categories.select { |c| c.has_category_moderators? }
  end

  def place_active
    if is_country
      return false if country_categories_active.blank?
      country_categories_active.length >= SiteSetting.place_country_active_min
    else
      true
    end
  end

  def self.members(category_id)
    User.where("id in (
      SELECT user_id FROM user_custom_fields
      WHERE name = '#{CivicallyPlace::Place.type(category_id)}_category_id'
      AND value = ?
    )", category_id.to_s)
  end

  def self.type(category_id)
    category = Category.find_by(category_id)
    category ? category.place_type : nil
  end

  def self.joined_at(user_id, type)
    UserHistory.where(
      action: UserHistory.actions["join_#{type}".to_sym],
      acting_user_id: user_id
    ).order(:created_at).last[:created_at].to_date
  end

  def self.home_country(user, category_id)
    place = CivicallyPlace::Place.new(id: category_id)
    place.is_country && place.country_categories_ids.include?(user.town_category_id)
  end

  def self.determine_type(geo_location)
    town_types = ['city', 'town', 'village']
    neighbourhood_types = ['neighbourhood']
    country_types = ['country']

    if country_types.include?(geo_location['type'])
      'country'
    elsif town_types.include?(geo_location['type'])
      'town'
    elsif neighbourhood_types.include?(geo_location['type'])
      'neighbourhood'
    else
      nil
    end
  end
end
