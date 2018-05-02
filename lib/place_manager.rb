DiscourseEvent.on(:vote_added) do |user, topic|
  if topic.category_id.to_i === SiteSetting.place_petition_category_id.to_i
    user.custom_fields['place_topic_id'] = topic.id
    CivicallyApp::App.update(user, 'civically-site', enabled: true)
    CivicallyPlace::User.add_pass_petition_to_checklist(user)
  end
end

DiscourseEvent.on(:vote_removed) do |user, topic|
  if topic.category_id.to_i === SiteSetting.place_petition_category_id.to_i
    user.custom_fields['place_topic_id'] = nil
  end
end

class PetitionTopicResult < ::NewPostResult; end

class CivicallyPlace::PlaceManager
  def self.create_petition_topic(user, opts)
    result = PetitionTopicResult.new(:created_petition_topic, false)

    geo_location = opts[:geo_location]
    name = geo_location['name']
    country = geo_location['country']
    title = I18n.t("petition.place.title", place: name, country: country)
    category_id = SiteSetting.place_petition_category_id
    identical = false

    # This is to handle places in the same country with identical names.
    # Geographic uniqueness is handled seperately in a location form validator (see plugin.rb).
    identical_place = Category.where(name: title)
    identical_petition = Topic.where(category_id: category_id, title: title)
    if identical_place.exists? || identical_petition.exists?
      identical = true
      identical_name = identical_place.exists? ? identical_place.first.name : identical_petition.first.title
      identical_url = identical_place.exists? ? identical_place.first.url : identical_petition.first.url
    end

    petition = CivicallyPetition::Petition.create(user,
      title: title,
      id: 'place',
      category: category_id
    )

    unless petition.errors.any?
      if identical
        SystemMessage.create_from_system_user(Discourse.site_contact_user,
          :identical_place_petition,
            title: petition.title,
            path: petition.url,
            identical_name: identical_name,
            identical_url: identical_url
        )
      end

      petition.custom_fields['location'] = {
        'geo_location': geo_location,
        'circle_marker': {
          'radius': 1,
          'color': '#FFA500',
          'routeTo': petition.relative_url
        }
      }.to_json

      petition.save_custom_fields(true)

      manager = NewPostManager.new(user,
        raw: opts[:raw],
        topic_id: petition.id,
        skip_validations: true
      )

      result = manager.perform
    end

    result
  end

  def self.update_user_count(category_id, count)
    place = CivicallyPlace::Place.find(category_id)
    user_count = (place.user_count || 0) + count

    place.custom_fields['user_count'] = user_count
    place.save_custom_fields(true)

    if user_count = place.user_count_min
      SystemMessage.create_from_system_user(Discourse.site_contact_user,
        :place_reached_user_count_min,
          place: place.name,
          path: place.url
      )
    end

    user_count
  end

  def self.create_place_category(topic_id)
    topic = Topic.find(topic_id)
    geo_location = topic.location['geo_location']
    parent_category = Category.find_by(slug: geo_location['countrycode'])
    result = {}

    if !parent_category
      countrycode = geo_location['countrycode']
      bounding_box = Locations::Country.bounding_boxes[countrycode]
      parent_category = create_category(
        name: geo_location['country'],
        slug: countrycode,
        permissions: { everyone: 2 },
        custom_fields: {
          'is_place': true,
          'place_type': 'country',
          'can_join': false,
          'location': {
            'name': geo_location['country'],
            'geo_location': {
              'boundingbox': bounding_box,
              'countrycode': countrycode,
              'type': 'country'
            },
            'flag': "/plugins/civically-place/images/flags/#{countrycode}_32.png",
            'route_to': "/c/#{countrycode}"
          }.to_json,
          'topic_list_social': "latest|new|unread|top|agenda|latest-mobile|new-mobile|unread-mobile|top-mobile|agenda-mobile",
          'topic_list_thumbnail': "latest|new|unread|top|agenda|latest-mobile|new-mobile|unread-mobile|top-mobile|agenda-mobile",
          'topic_list_excerpt': "latest|new|unread|top|agenda|latest-mobile|new-mobile|unread-mobile|top-mobile|agenda-mobile",
          'topic_list_action': "latest|unread|top|new|agenda|latest-mobile|new-mobile|unread-mobile|top-mobile|agenda-mobile",
          'topic_list_thumbnail_width': 600,
          'topic_list_thumbnail_height': 300
        }
      )

      parent_category.save!
    end

    if !parent_category || !parent_category.id
      return { error: I18n.t('place.topic.error.parent_category_creation') }
    end

    category = create_category(
      name: geo_location['name'],
      permissions: { everyone: 1 },
      parent_category_id: parent_category.id,
      custom_fields: {
        'is_place': true,
        'can_join': true,
        'place_type': 'town',
        'topic_list_social': "latest|new|unread|top|agenda|latest-mobile|new-mobile|unread-mobile|top-mobile|agenda-mobile",
        'topic_list_thumbnail': "latest|new|unread|top|agenda|latest-mobile|new-mobile|unread-mobile|top-mobile|agenda-mobile",
        'topic_list_excerpt': "latest|new|unread|top|agenda|latest-mobile|new-mobile|unread-mobile|top-mobile|agenda-mobile",
        'topic_list_action': "latest|unread|top|new|agenda|latest-mobile|new-mobile|unread-mobile|top-mobile|agenda-mobile",
        'topic_list_thumbnail_width': 600,
        'topic_list_thumbnail_height': 300
      }
    )

    if !category || !category.id
      return { error: I18n.t('place.topic.error.category_creation') }
    end

    topic.category_id = category.id
    topic.custom_fields.delete('petition')
    topic.custom_fields.delete('petition_id')
    topic.custom_fields.delete('petition_status')
    topic.custom_fields.delete('location')
    topic.save!

    category.topic_id = topic.id
    category.custom_fields['location'] = {
      'geo_location': geo_location,
      'circle_marker': {
        'radius': 1,
        'color': '#08c',
        'routeTo': topic.relative_url
      }
    }.to_json
    category.save!

    result[:category_id] = category.id

    DiscourseEvent.trigger(:place_created, category)

    Scheduler::Defer.later "Log staff action create category" do
      StaffActionLogger.new(current_user).log_category_creation(category)
    end

    result
  end

  def self.setup_place(category_id)
    category = Category.find(category_id)
    topic = Topic.find(category.topic_id)
    user = Discourse.system_user

    moderator_topic_result = DiscourseElections::ElectionTopic.create(user,
      title: I18n.t('place.election.title', place: category.name, position: "Moderator"),
      category_id: category.id,
      position: "moderator",
      self_nomination_allowed: true,
      status_banner: true,
      status_banner_result_hours: SiteSetting.elections_status_banner_default_result_hours.to_i,
      nomination_message: I18n.t('place.moderator_election.nomination_message', place: category.name),
      poll_message: I18n.t('place.moderator_election.poll_message', place: category.name),
      closed_poll_message: I18n.t('place.moderator_election.closed_poll_message', place: category.name),
      poll_open: true,
      poll_open_after: true,
      poll_open_after_hours: 72,
      poll_open_after_nominations: 3,
      poll_close: true,
      poll_close_after: true,
      poll_close_after_hours: 72,
      poll_close_after_voters: 50
    )

    user_errors = []
    supporters = topic.petition_supporters

    supporters.each do |user|
      user_result = User.update_place_category_id(user, category.id)

      if user_result[:error]
        user_errors.push(user: user.username, error: user_result[:error])
      end

      points = 0

      Invite.where(invited_by_id: user.id).where.not(redeemed_at: nil).each do |invite|
        if invite.user_id && supporters.select { |s| s.id == invite.user_id }.any?
          points += 1
        end
      end

      if topic.user_id == user.id
        points += 3
      end

      user.place_points[category.id] = user.place_points[category.id].to_i + points
      user.custom_fields['place_points'] = user.place_points

      user.save_custom_fields(true)
    end

    ranked_supporters = topic.petition_supporters
      .sort_by { |u| [u.place_points[category.id], u.created_at] }
      .reverse!

    ranked_supporters.each_with_index do |user, index|
      if index === 0
        BadgeGranter.grant(Badge.find(Badge::Founder), user)
      elsif index > 0 && index < 4
        BadgeGranter.grant(Badge.find(Badge::Pathfinder), user)
      else
        BadgeGranter.grant(Badge.find(Badge::Pioneer), user)
      end
    end

    error_messages = ''

    if user_errors.any?
      error_messages += user_errors.map do |e|
        I18n.t('place.topic.error.petition_supporter', user: e[:user], message: e[:error])
      end.join(', ')
    end

    if moderator_topic_result[:error_message]
      error_messages += "\n\n"
      error_messages += I18n.t('place.topic.error.election_topic_creation',
        type: "Moderator",
        message: moderator_topic_result[:error_message]
      )
    end

    if error_messages.present?
      Jobs.enqueue(:notify_moderators_of_place_creation_errors,
        error_messages: error_messages,
        category_id: category.id
      )
    end
  end

  def self.create_category(opts)
    Category.create(opts.merge(
      user: Discourse.system_user,
      color: SecureRandom.hex(3),
      allow_badges: true,
      text_color: 'FFFFF',
      topic_featured_link_allowed: true
    ))
  end
end
