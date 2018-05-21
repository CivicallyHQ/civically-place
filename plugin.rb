# name: civically-place
# app: store
# about: Provides the place logic for Civically
# version: 0.1
# dependencies: discourse-locations, civically-navigation, discourse-layouts, civically-petition, discourse-search-addons
# authors: angus
# url: https://github.com/civicallyhq/civically-place

register_asset "stylesheets/common/place.scss"
register_asset "stylesheets/mobile/place.scss", :mobile

DiscourseEvent.on(:petition_ready) do
  CivicallyPetition::Petition.add_resolution('place') do |topic, forced|
    status = topic.custom_fields['petition_status']
    result = {}

    if status === 'accepted'
      if !forced && topic.petition_supporters.length < topic.petition_vote_threshold
        result[:error] = I18n.t('place.topic.error.insufficient_supporters')
      else
        result = CivicallyPlace::PlaceManager.create_from_petition(topic.id)
      end

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
    if context === 'place_petition' || context === 'place_add'
      permitted_types = context === 'place_add' ? SiteSetting.place_add_types.split('|') :
                                                  SiteSetting.place_petition_types.split('|')

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
    if context === 'place_petition' || context === 'place_add'
      identical_place = CategoryCustomField.where(name: 'place_id', value: geo_location['osm_id'])

      response = {}
      if identical_place.exists?
        category = Category.find(identical_place.pluck(:category_id))
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
  ## 'migration' to be wrapped in conditional
  CustomWizard::Wizard.add_wizard(File.read(File.join(
    Rails.root, 'plugins', 'civically-place', 'config', 'wizards', 'place_petition.json'
  )))

  CustomWizard::Field.add_assets('prefilled-composer', 'civically-place', ['components'])

  CustomWizard::Builder.add_step_handler('place_petition') do |builder|
    updater = builder.updater

    if builder.updater && builder.updater.step && builder.updater.step.id === 'location'
      input = builder.updater.fields.to_h

      if builder.submissions.empty?
        builder.submissions.push({})
      end

      default_post = I18n.t('place.petition.topic.post.default', placeName: input['location']['city'])
      builder.submissions.last["post"] = default_post

      builder.updater.refresh_required = true
    end

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

        CivicallyChecklist::Checklist.add_item(user, {
          id: "pass_petition",
          checked: false,
          checkable: false,
          active: true,
          title: I18n.t('checklist.place_setup.pass_petition.title'),
          detail: I18n.t('checklist.place_setup.pass_petition.detail')
        }, 1)

        CivicallyChecklist::Checklist.update_item(user, 'set_place', active: false)

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
    get "set" => "place_user#index"
    post "set" => "place_user#set"
    post "add" => "place_manage#add"
  end

  Discourse::Application.routes.append do
    mount ::CivicallyPlace::Engine, at: "place"
    %w{users u}.each_with_index do |root_path, index|
      get "#{root_path}/:username/place" => "users#show", constraints: { username: USERNAME_ROUTE_FORMAT }
    end
  end

  load File.expand_path('../models/place.rb', __FILE__)
  load File.expand_path('../controllers/place.rb', __FILE__)
  load File.expand_path('../controllers/place_user.rb', __FILE__)
  load File.expand_path('../controllers/place_manage.rb', __FILE__)
  load File.expand_path('../jobs/notify_moderators_of_place_creation_errors.rb', __FILE__)
  load File.expand_path('../lib/place_manager.rb', __FILE__)
  load File.expand_path('../lib/place_badges.rb', __FILE__)
  load File.expand_path('../lib/place_user.rb', __FILE__)
  load File.expand_path('../lib/place_category.rb', __FILE__)

  add_to_serializer(:basic_category, :topic_id) { object.topic_id }
  add_to_serializer(:basic_category, :is_place) { object.is_place }

  add_to_serializer(:user, :place) {
    BasicCategorySerializer.new(object.place, scope: scope, root: false)
  }
  add_to_serializer(:user, :include_place?) { object.place_category_id.present? }
  add_to_serializer(:current_user, :place) {
    BasicCategorySerializer.new(object.place, scope: scope, root: false)
  }
  add_to_serializer(:current_user, :include_place?) { object.place_category_id.present? }

  add_to_serializer(:user, :place_joined_at) { object.place_joined_at }
  add_to_serializer(:user, :include_place_joined_at?) { object.place_category_id.present? }
  add_to_serializer(:current_user, :place_joined_at) { object.place_joined_at }
  add_to_serializer(:current_user, :include_place_joined_at?) { object.place_category_id.present? }

  add_to_serializer(:user, :place_points) {
    object.place_category_id ? object.place_points[object.place_category_id.to_s] : 0
  }
  add_to_serializer(:current_user, :place_points) {
    object.place_category_id ? object.place_points[object.place_category_id.to_s] : 0
  }

  add_to_serializer(:user, :place_category_id) { object.place_category_id }
  add_to_serializer(:user, :place_topic_id) { object.place_topic_id }
  add_to_serializer(:current_user, :place_category_id) { object.place_category_id }
  add_to_serializer(:current_user, :place_topic_id) { object.place_topic_id }
  add_to_serializer(:admin_user_list, :place_category_id) { object.place_category_id }
  add_to_serializer(:admin_user_list, :place_topic_id) { object.place_topic_id }

  add_to_serializer(:current_user, :added_place_id) { object.added_place_id }
  add_to_serializer(:current_user, :include_added_place_id?) { object.added_place_id.present? }

  DiscourseEvent.trigger(:place_ready)
end
