# name: civically-place
# about: Provides the place logic for Civically
# version: 0.1
# dependencies: discourse-locations, civically-navigation, discourse-layouts, civically-petition, discourse-search-addons
# authors: angus
# url: https://github.com/civicallyhq/civically-place

register_asset "stylesheets/civically-place.scss"

DiscourseEvent.on(:petition_ready) do
  CivicallyPetition::Petition.add_resolution('place') do |topic, forced|
    status = topic.custom_fields['petition_status']
    result = {}

    if status === 'accepted'
      result = CivicallyPlace::Place.create(topic.id, forced)

      if result[:error]
        result[:message] = result[:error]
      end

      if result[:category_id]
        category = Category.find(result[:category_id])
        result[:route_to] = category.url
      end
    end

    if status === 'rejected'
      topic.closed = true
    end

    topic.save!

    result
  end
end

DiscourseEvent.on(:civically_site_ready) do
  unless SiteSetting.place_petition_category_id.to_i > 1
    category = Category.create(
      user: Discourse.system_user,
      name: 'Place',
      color: SecureRandom.hex(3),
      permissions: { everyone: 2 },
      allow_badges: true,
      text_color: 'FFFFF',
      topic_id: -1,
      topic_featured_link_allowed: true,
      parent_category_id: SiteSetting.petition_category_id,
      custom_fields: {
       'meta': true,
       'enable_topic_voting': "true",
       'petition_enabled': true,
       'petition_vote_threshold': 100,
       'tl0_vote_limit': 1,
       'tl1_vote_limit': 1,
       'tl2_vote_limit': 1,
       'tl3_vote_limit': 1,
       'tl4_vote_limit': 1
      }
    )
    SiteSetting.place_petition_category_id = category.id
  end
end

DiscourseEvent.on(:locations_ready) do
  Locations::Geocode.add_options do |options, context|
    options[:lookup] = :nominatim if context === 'place_petition'
    options
  end

  class Locations::GeoLocationSerializer
    attributes :osm_id

    def osm_id
      object.osm_id
    end

    def include_osm_id?
      object.respond_to?(:osm_id)
    end
  end

  Place = Struct.new(:osm_id, :boundingbox, :latitude, :longitude, :address, :name, :state, :country, :country_code, :type)

  Locations::Geocode.add_filter do |locations, context|
    if context === 'place_petition'
      permitted_types = SiteSetting.place_permitted_types.split('|')
      locations.select! { |l| l.data['class'] === 'place' && permitted_types.include?(l.data['type']) }
      locations.map! do |l|
        country_code = l.data['address']['country_code']
        country = Locations::Country.codes.select { |c| c[:code] == country_code }.first[:name]
        type = l.data['type']
        Place.new(
          l.data['osm_id'],
          l.data['boundingbox'],
          l.data['lat'],
          l.data['lon'],
          l.data['display_name'],
          l.data['address'][type],
          l.data['address']['state'],
          country,
          country_code,
          type
        )
      end
    end

    locations
  end

  Locations::Geocode.add_validator do |geo_location, context|
    if context === 'place_petition'
      osm_id = geo_location['osm_id'].to_i
      identical_places = CategoryCustomField.where(name: 'location').select do |l|
        location = ::JSON.parse(l['value'])
        location['geo_location']['osm_id'].to_i === osm_id
      end

      response = {}
      if identical_places.first
        category = Category.find(identical_places.first[:category_id])
        response['message'] = I18n.t("place.petition.location.validation.place_exists",
          category_url: category.url,
          category_name: category.name
        )
      else
        Topic.where(category_id: SiteSetting.place_petition_category_id).each do |topic|
          if topic && topic.location && topic.location['geo_location'] &&
             topic.location['geo_location']['osm_id'].to_i === osm_id
            response['message'] = I18n.t('place.petition.location.validation.petition_exists',
              topic_url: topic.url,
              topic_title: topic.title
            )
          end
        end
      end

      response
    end
  end
end

DiscourseEvent.on(:custom_wizard_ready) do
  unless PluginStoreRow.exists?(plugin_name: 'custom_wizard', key: 'place_petition')
    CustomWizard::Wizard.add_wizard(File.read(File.join(
      Rails.root, 'plugins', 'civically-place', 'config', 'wizards', 'place_petition.json'
    )))
  end

  CustomWizard::Builder.add_step_handler('place_petition') do |builder|
    if builder.updater && builder.updater.step && builder.updater.step.id === 'submit'
      updater = builder.updater
      submission = builder.submissions.last || {}
      user = builder.wizard.user

      updater.errors.add(:place_petition, I18n.t('place.petition.submit.error')) if !submission
      updater.errors.add(:place_petition, I18n.t('place.petition.location.error')) if !submission['location']
      updater.errors.add(:place_petition, I18n.t('place.petition.post.error')) if !submission['post']

      unless updater.errors.any?
        result = CivicallyPlace::PlaceManager.create_petition_topic(user,
          geo_location: submission['location']['geo_location'],
          raw: submission['post']
        )

        if result.errors.any?
          updater.errors.add(:place_petition, result.errors.full_messages.join("\n"))
        else
          user.custom_fields['place_topic_id'] = result.post.topic_id
          user.save!
          updater.result = { redirect_to: result.post.url }
        end
      end
    end
  end
end

after_initialize do
  Category.register_custom_field_type('place', :boolean)
  Category.register_custom_field_type('place_can_join', :boolean)
  Category.register_custom_field_type('place_user_count', :integer)
  Category.register_custom_field_type('place_user_count_min', :integer)
  Category.register_custom_field_type('place_location', :json)
  User.register_custom_field_type('place_category_id', :integer)
  User.register_custom_field_type('place_topic_id', :integer)
  Group.register_custom_field_type('category_id', :integer)

  require_dependency "application_controller"
  module ::CivicallyPlace
    class Engine < ::Rails::Engine
      engine_name "civically_place"
      isolate_namespace CivicallyPlace
    end
  end

  CivicallyPlace::Engine.routes.draw do
    get "get/:category_id" => "place#get"
    get "list" => "place#list"
    get "check_if_unique" => "place#check_if_unique"
    get "groups" => "place#groups"
    get "events" => "place#events"
    get "petitions" => "place#petitions"
    get "ratings" => "place#ratings"
    get "set" => "user_place#index"
    post "set" => "user_place#set_place"
    get "add" => "user_place#index"
  end

  Discourse::Application.routes.append do
    mount ::CivicallyPlace::Engine, at: "place"
    %w{users u}.each_with_index do |root_path, index|
      get "#{root_path}/:username/place" => "users#show", constraints: { username: USERNAME_ROUTE_FORMAT }
    end
  end

  load File.expand_path('../models/place.rb', __FILE__)
  load File.expand_path('../controllers/place.rb', __FILE__)
  load File.expand_path('../controllers/user_place.rb', __FILE__)
  load File.expand_path('../jobs/notify_moderators_of_place_creation_errors.rb', __FILE__)
  load File.expand_path('../lib/place_manager.rb', __FILE__)
  load File.expand_path('../serializers/place.rb', __FILE__)
  load File.expand_path('../serializers/place_user.rb', __FILE__)

  UserHistory.actions[:place] = 1001

  User.class_eval do
    def place_category_id
      if self.custom_fields['place_category_id']
        self.custom_fields['place_category_id']
      else
        nil
      end
    end

    def self.update_place_category_id(user, category_id, force = nil)
      place = CivicallyPlace::Place.new(category_id, user)

      if !place
        return { error: I18n.t('user.errors.place_not_found') }
      end

      if place.member
        return { error: I18n.t('user.errors.place_not_changed') }
      end

      if user.place_category_id
        user_place = CivicallyPlace::Place.new(user.place_category_id, user)
        change_min = SiteSetting.place_change_min.to_i

        if !force && (Time.now.to_date - user_place.joined_at).round < change_min
          next_time = (user_place.joined_at + change_min).strftime("%B %d")
          past_time = user_place.joined_at.strftime("%B %d")

          return {
            error: I18n.t('user.errors.place_set_limit',
              past_time: past_time,
              place: user_place.category.name,
              next_time: next_time,
              change_min: change_min),
            status: 403
          }
        end

        CivicallyPlace::PlaceManager.update_user_count(user_place.category.id, -1)
      end

      CivicallyPlace::PlaceManager.update_user_count(category_id, 1)

      UserHistory.create(
        action: UserHistory.actions[:place],
        acting_user_id: user.id,
        category_id: category_id
      )

      user.custom_fields['place_category_id'] = category_id
      user.save_custom_fields(true)

      { place_category_id: user.place_category_id }
    end
  end

  Category.class_eval do
    def create_category_definition
      nil
    end

    def place
      ActiveModel::Type::Boolean.new.cast(self.custom_fields['place'])
    end

    def place_can_join
      self.custom_fields['place_can_join']
    end

    def country
      place && !place_can_join
    end

    def child_categories
      Category.where(parent_category_id: id)
    end

    def country_categories
      return [] if child_categories.blank?
      child_categories.select { |c| c.place }
    end

    def country_categories_ids
      country_categories.map { |c| c.id }
    end

    def country_categories_active
      return [] if country_categories.blank?
      country_categories.select { |c| c.has_category_moderators? }
    end

    def country_active
      return false if country_categories_active.blank?
      country_categories_active.length >= SiteSetting.place_country_active_min
    end

    def self.is_home_country(user, category)
      category.country &&
      category.country_categories_ids.include?(user.place_category_id)
    end
  end

  DiscourseEvent.on(:vote_added) do |user, topic|
    if topic.category_id === SiteSetting.place_petition_category_id
      user.custom_fields['place_topic_id'] = topic.id
    end
  end

  DiscourseEvent.on(:vote_removed) do |user, topic|
    if topic.category_id === SiteSetting.place_petition_category_id
      user.custom_fields['place_topic_id'] = nil
    end
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
        (category.id === user.place_category_id ||
        ## or user's country
        Category.is_home_country(user, category) ||
        ## or is a meta category
        category.meta))
    end
  end

  # If a user is invited to a petition topic it should be set as their place topic id
  module InvitesControllerCivicallyUser
    private def post_process_invite(user)
      super(user)
      if user
        invite = Invite.find_by(invite_key: params[:id])
        topic = invite.topics.first
        if topic && topic.petition && topic.petition_status === 'open'
          user.custom_fields['place_topic_id'] = topic.id
          user.save_custom_fields(true)
        end
      end
    end
  end

  require_dependency 'invites_controller'
  class ::InvitesController
    prepend InvitesControllerCivicallyUser
  end

  add_to_serializer(:basic_category, :topic_id) { object.topic_id }
  add_to_serializer(:basic_category, :place) { object.place }
  add_to_serializer(:basic_category, :place_can_join) { object.place_can_join }
  add_to_serializer(:basic_category, :include_place_can_join) { object.place }
  add_to_serializer(:basic_category, :place_user) { object.custom_fields["place_users"] }
  add_to_serializer(:basic_category, :include_place_user) { object.place }
  add_to_serializer(:basic_category, :place_user_count) { object.custom_fields["place_user_count"] }
  add_to_serializer(:basic_category, :include_place_user_count) { object.place }
  add_to_serializer(:basic_category, :place_user_count_min) { object.custom_fields["place_user_count"] }
  add_to_serializer(:basic_category, :include_place_user_count_min) { object.place }
  add_to_serializer(:basic_category, :place_location) { object.custom_fields["place_location"] }
  add_to_serializer(:basic_category, :include_place_location) { object.place }
  add_to_serializer(:basic_category, :place_country) { object.country }
  add_to_serializer(:basic_category, :include_place_country) { object.place }
  add_to_serializer(:basic_category, :place_country_active) { object.country_active }
  add_to_serializer(:basic_category, :include_place_country_active) { object.country }
  add_to_serializer(:current_user, :place_category_id) { object.custom_fields["place_category_id"] }
  add_to_serializer(:admin_user_list, :place_category_id) { object.custom_fields["place_category_id"] }
  add_to_serializer(:current_user, :place_topic_id) { object.custom_fields["place_topic_id"] }
  add_to_serializer(:admin_user_list, :place_topic_id) { object.custom_fields["place_topic_id"] }
  add_to_serializer(:basic_group, :category_id) { object.custom_fields["category_id"] }

  DiscourseEvent.trigger(:place_ready)
end
