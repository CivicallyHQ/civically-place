DiscourseEvent.on(:vote_added) do |user, topic|
  if topic.category_id.to_i === SiteSetting.place_petition_category_id.to_i &&
     !user.place_category_id

    user.custom_fields['place_topic_id'] = topic.id

    CivicallyChecklist::Checklist.add_item(user, {
      id: "pass_petition",
      checked: false,
      checkable: false,
      active: true,
      title: I18n.t('checklist.place_setup.pass_petition.title'),
      detail: I18n.t('checklist.place_setup.pass_petition.detail')
    }, 1)

    CivicallyChecklist::Checklist.update_item(user, 'set_place', active: false)
  end
end

DiscourseEvent.on(:vote_removed) do |user, topic|
  if topic.category_id.to_i === SiteSetting.place_petition_category_id.to_i &&
     topic.id === user.place_topic_id.to_i
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
      category: category_id,
      messages: {
        user: {
          no_vote: I18n.t('petition.place.user.no_vote', place: name, country: country),
          vote: I18n.t('petition.place.user.vote', place: name, country: country)
        },
        petitioner: {
          vote: I18n.t('petition.place.user.vote', place: name, country: country)
        },
        info: I18n.t('petition.place.info', place: name, country: country)
      }
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
        skip_validations: true,
        skip_guardian: true
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

  def self.create(geo_location, user)
    if !user.admin && user.added_place.exists?
      return { error: I18n.t('place.add.error.only_one') }
    end

    parent_id = nil
    category_id = nil

    Category.transaction do
      if country_category = Category.find_by(slug: geo_location['countrycode'])
        parent_id = country_category.id
      else
        country_category = build_country(geo_location)
        country_topic_title = geo_location['country']
        country_topic = build_about_topic(country_topic_title, country_category.id)

        parent_id = finalise_place_creation(country_category, country_topic, geo_location,
          add_marker: false
        )
      end

      if !parent_id
        return { error: I18n.t('place.topic.error.parent_category_creation') }
      end

      if CategoryCustomField.exists?(name: 'place_id', value: geo_location['osm_id'])
        return { error: I18n.t('place.topic.error.place_exists') }
      end

      category = build_place(parent_id, geo_location)

      if !category || !category.id
        return { error: I18n.t('place.topic.error.category_creation') }
      end

      topic_title = geo_location['name'] + ', ' + geo_location['country']
      topic = build_about_topic(topic_title, category.id)

      category_id = finalise_place_creation(category, topic, geo_location,
        user: user,
        add_marker: true
      )
    end

    { category_id: category_id }
  end

  def self.create_from_petition(topic_id)
    topic = Topic.find(topic_id)
    geo_location = topic.location['geo_location']
    parent = {} ## TO FILL
    category_id = nil

    Category.transaction do
      category = build_place(parent, geo_location)

      if !category || !category.id
        return { error: I18n.t('place.topic.error.category_creation') }
      end

      topic.category_id = category.id
      topic.subtype = nil
      topic.title = I18n.t('place.about.title', place: geo_location['name'], parent: geo_location['country'])

      topic.custom_fields.delete('petition')
      topic.custom_fields.delete('petition_id')
      topic.custom_fields.delete('petition_status')
      topic.custom_fields.delete('location')

      topic.save!(validate: false)

      category_id = finalise_place_creation(category, topic, geo_location,
        add_marker: true
      )
    end

    after_place_petition(category_id)

    { category_id: category_id }
  end

  def self.finalise_place_creation(category, topic, geo_location, opts)
    category.topic_id = topic.id

    if opts[:add_marker]
      category.custom_fields['location'] = {
        'geo_location': geo_location,
        'circle_marker': {
          'radius': 1,
          'color': '#08c',
          'routeTo': topic.relative_url
        }
      }.to_json
    end

    category.save!

    DiscourseEvent.trigger(:place_created, category)

    user = opts[:user] ? opts[:user] : Discourse.system_user

    Scheduler::Defer.later "Log staff action create category" do
      StaffActionLogger.new(user).log_category_creation(category)
    end

    category.id
  end

  def self.build_about_topic(title, category_id)
    topic = Topic.new(
      title: title,
      user: Discourse.system_user,
      category_id: category_id
    )

    topic.skip_callbacks = true
    topic.ignore_category_auto_close = true
    topic.delete_topic_timer(TopicTimer.types[:close])
    topic.save!(validate: false)

    topic.posts.create(
      raw: I18n.t('place.about.post', place: title),
      user: Discourse.system_user
    )

    topic
  end

  def self.build_place(parent_id, geo_location)
    create_category(
      name: geo_location['name'],
      permissions: { everyone: 1 },
      parent_category_id: parent_id,
      custom_fields: {
        'is_place': true,
        'can_join': true,
        'place_type': geo_location['type'],
        'place_id': geo_location['osm_id'],
        'topic_list_social': "latest|new|unread|top|agenda|latest-mobile|new-mobile|unread-mobile|top-mobile|agenda-mobile",
        'topic_list_thumbnail': "latest|new|unread|top|agenda|latest-mobile|new-mobile|unread-mobile|top-mobile|agenda-mobile",
        'topic_list_excerpt': "latest|new|unread|top|agenda|latest-mobile|new-mobile|unread-mobile|top-mobile|agenda-mobile",
        'topic_list_action': "latest|unread|top|new|agenda|latest-mobile|new-mobile|unread-mobile|top-mobile|agenda-mobile",
        'topic_list_thumbnail_width': 600,
        'topic_list_thumbnail_height': 300
      }
    )
  end

  def self.build_country(geo_location)
    countrycode = geo_location['countrycode']
    bounding_box = Locations::Country.bounding_boxes[countrycode]

    create_category(
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
  end

  def self.after_place_petition(category_id)
    category = Category.find(category_id)
    topic = Topic.find(category.topic_id)
    user = Discourse.system_user

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

    if error_messages.present?
      Jobs.enqueue(:notify_moderators_of_place_creation_errors,
        error_messages: error_messages,
        category_id: category.id
      )
    end

    true
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
