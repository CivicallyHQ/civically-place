User.register_custom_field_type('place_category_id', :integer)
User.register_custom_field_type('place_topic_id', :integer)
User.register_custom_field_type('place_points', :json)

UserHistory.actions[:place] = 1001

DiscourseEvent.on(:post_created) do |post, opts, user|
  if (user.user_stat.topic_count < 2 && user.user_stat.post_count < 2)
    CivicallyChecklist::Checklist.update_item(user, 'post', checked: true)
  end
end

require_dependency 'user'
class ::User

  def place
    if place_category_id
      @place ||= CivicallyPlace::Place.find(place_category_id)
    else
      nil
    end
  end

  def place_joined_at
    if place_category_id
      @place_joined_at ||= CivicallyPlace::Place.joined_at(self.id)
    else
      nil
    end
  end

  def place_category_id
    if self.custom_fields['place_category_id']
      self.custom_fields['place_category_id']
    else
      nil
    end
  end

  def place_topic_id
    if self.custom_fields['place_topic_id']
      self.custom_fields['place_topic_id']
    else
      nil
    end
  end

  def place_points
    if self.custom_fields['place_points']
      self.custom_fields['place_points']
    else
      {}
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

  def self.update_place_category_id(user, category_id, force = nil)
    place = CivicallyPlace::Place.find(category_id)

    if !place
      return { error: I18n.t('user.errors.place_not_found') }
    end

    if place.id === user.place_category_id
      return { error: I18n.t('user.errors.place_not_changed') }
    end

    is_first_place = false

    if user.place_category_id
      user_place = CivicallyPlace::Place.find(user.place_category_id)
      joined_at = CivicallyPlace::Place.joined_at(user.id)
      change_min = SiteSetting.place_change_min.to_i

      if !force && (Time.now.to_date - joined_at).round < change_min
        next_time = (joined_at + change_min).strftime("%B %d")
        past_time = joined_at.strftime("%B %d")

        return {
          error: I18n.t('user.errors.place_set_limit',
            past_time: past_time,
            place: user_place.name,
            next_time: next_time,
            change_min: change_min),
          status: 403
        }
      end

      CivicallyPlace::PlaceManager.update_user_count(user_place.id, -1)
    else
      is_first_place = true
    end

    CivicallyPlace::PlaceManager.update_user_count(category_id, 1)

    UserHistory.create(
      action: UserHistory.actions[:place],
      acting_user_id: user.id,
      category_id: category_id
    )

    user.custom_fields['place_category_id'] = category_id

    user.place_points[category_id] = 0
    user.custom_fields['place_points'] = user.place_points

    user.save_custom_fields(true)

    after_first_place_set(user) if is_first_place

    {
      place: BasicCategorySerializer.new(user.place, root: false),
      place_joined_at: user.place_joined_at,
      place_points: user.place_points,
      place_category_id: user.place_category_id,
      app_data: CivicallyApp::App.user_app_data(user)
    }
  end

  def self.after_first_place_set(user)
    CivicallyChecklist::Checklist.update_item(user, 'set_place', checked: true, active: true)
    CivicallyChecklist::Checklist.update_item(user, 'pass_petition', checked: true, active: true)
  end
end
