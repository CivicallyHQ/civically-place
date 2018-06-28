User.register_custom_field_type('town_category_id', :integer)
User.register_custom_field_type('neighbourhood_category_id', :integer)
User.register_custom_field_type('neighbourhood_petition_id', :integer)
User.register_custom_field_type('place_points', :json)

UserHistory.actions[:join_town] = 1001
UserHistory.actions[:join_neighbourhood] = 1002

DiscourseEvent.on(:post_created) do |post, opts, user|
  if (user.user_stat.topic_count < 2 && user.user_stat.post_count < 2)
    CivicallyChecklist::Checklist.update_item(user, 'post', checked: true, hideable: true)
  end
end

require_dependency 'user'
class ::User

  def town
    if town_category_id
      @town ||= CivicallyPlace::Place.find(town_category_id)
    else
      nil
    end
  end

  def town_joined_at
    if town_category_id
      @town_joined_at ||= CivicallyPlace::Place.joined_at(self.id, 'town')
    else
      nil
    end
  end

  def town_category_id
    if self.custom_fields['town_category_id']
      self.custom_fields['town_category_id'].to_i
    else
      nil
    end
  end

  def neighbourhood
    if neighbourhood_category_id
      @neighbourhood ||= CivicallyPlace::Place.find(neighbourhood_category_id)
    else
      nil
    end
  end

  def neighbourhood_joined_at
    if neighbourhood_category_id
      @neighbourhood_joined_at ||= CivicallyPlace::Place.joined_at(self.id, 'neighbourhood')
    else
      nil
    end
  end

  def neighbourhood_category_id
    if self.custom_fields['neighbourhood_category_id']
      self.custom_fields['neighbourhood_category_id'].to_i
    else
      nil
    end
  end

  def neighbourhood_petition_id
    if self.custom_fields['neighbourhood_petition_id']
      self.custom_fields['neighbourhood_petition_id'].to_i
    else
      nil
    end
  end

  def place_home
    if town_category_id
      if self.custom_fields['place_home']
        self.custom_fields['place_home']
      else
        'town'
      end
    else
      nil
    end
  end

  def place_points
    @place_points ||= begin
      if self.custom_fields['place_points']
        self.custom_fields['place_points']
      else
        {}
      end
    end
  end

  def town_points
    if town_category_id
      place_points[town_category_id].to_i
    else
      0
    end
  end

  def neighbourhood_points
    if neighbourhood_category_id
      place_points[neighbourhood_category_id].to_i
    else
      0
    end
  end

  def added_place
    UserHistory.where(
      acting_user_id: self.id,
      action: UserHistory.actions[:create_category]
    )
  end

  def added_place_id
    @added_place_id ||= added_place.pluck(:category_id)[0]
  end

  def self.update_town_category_id(user, category_id, force = nil)
    update_category_id(user, category_id, force, 'town')
  end

  def self.update_neighbourhood_category_id(user, category_id, force = nil)
    update_category_id(user, category_id, force, 'neighbourhood')
  end

  def self.update_category_id(user, category_id, force, type)
    place = CivicallyPlace::Place.find(category_id)

    if !place
      return { error: I18n.t("user.errors.#{type}_not_found") }
    end

    current_id = user.send("#{type}_category_id")

    if place.id === current_id
      return { error: I18n.t("user.errors.#{type}_not_changed") }
    end

    is_first = false

    if current_id
      can_change = self.can_change_place(user, current_id, force, type)

      return can_change if can_change[:error]

      CivicallyPlace::PlaceManager.update_user_count(current_id, -1)
    else
      is_first = true
    end

    CivicallyPlace::PlaceManager.update_user_count(category_id, 1)

    UserHistory.create(
      action: UserHistory.actions["join_#{type}".to_sym],
      acting_user_id: user.id,
      category_id: category_id
    )

    user.custom_fields["#{type}_category_id"] = category_id
    user.save_custom_fields(true)

    self.send("after_first_#{type}_set", user) if is_first

    result = {}.with_indifferent_access
    result[type] = BasicCategorySerializer.new(user.send(type), root: false)
    result["#{type}_joined_at".to_sym] = user.send("#{type}_joined_at")
    result["#{type}_category_id".to_sym] = user.send("#{type}_category_id")

    result
  end

  def self.can_change_place(user, current_id, force, type)
    user_place = CivicallyPlace::Place.find(current_id)
    joined_at = CivicallyPlace::Place.joined_at(user.id, type)
    change_min = SiteSetting.send("place_#{type}_change_min").to_i

    if !force && (Time.now.to_date - joined_at).round < change_min
      next_time = (joined_at + change_min).strftime("%B %d")
      past_time = joined_at.strftime("%B %d")

      {
        error: I18n.t("user.errors.#{type}_set_limit",
          past_time: past_time,
          place: user_place.name,
          next_time: next_time,
          change_min: change_min
        )
      }
    end

    { success: true }
  end

  def self.after_first_town_set(user)
    CivicallyChecklist::Checklist.update_item(user, 'set_town', checked: true, hideable: true)
  end

  def self.after_first_neighbourhood_set(user)
    CivicallyChecklist::Checklist.update_item(user, 'pass_petition', checked: true, hideable: true)
  end
end

module GuardianPlaceExtension
  ## Consider whether there should be any place restrictions on can_create_post

  def can_create_topic_on_category?(category)
    return false unless super(category)
    return true if is_staff? || !category

    ## is user's neighbourhood
    (category.is_place && (category.id === user.neighbourhood_category_id ||

    ## is user's town
    category.id === user.town_category_id ||

    ## or user's country
    CivicallyPlace::Place.home_country(category.id, user))) ||

    ## or is a meta category
    category.meta
  end
end

require_dependency 'guardian'
class ::Guardian
  prepend GuardianPlaceExtension
end
