# name: civically-place
# app: store
# about: Provides the place logic for Civically
# version: 0.1
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
        result = CivicallyPlace::PlaceManager.create_neighbourhood(topic.id)
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
  class Locations::GeoLocationSerializer
    attributes :osm_id

    def osm_id
      object.osm_id
    end

    def include_osm_id?
      object.respond_to?(:osm_id)
    end
  end

  Locations::Geocode.add_filter do |locations, options|
    options[:place_type] = 'town' if options[:context] === 'place_add'
    options[:place_type] = 'neighbourhood' if options[:context] === 'neighbourhood_petition'

    if options[:place_type]
      locations = CivicallyPlace::Locations.filter(locations, options)
      locations = CivicallyPlace::Locations.format(locations, options)
    end

    locations
  end

  Locations::Geocode.add_validator do |geo_location, context|
    if context === 'neighbourhood_petition' || context === 'place_add'
      return {
        message: I18n.t('place.validation.osm_id')
      } if !geo_location['osm_id']

      osm_id = geo_location['osm_id'].to_i

      if identical_place = CategoryCustomField.find_by(name: 'place_id', value: osm_id)
        category = Category.find(identical_place.category_id)

        return {
          message: I18n.t("place.validation.place_exists",
            category_url: category.url,
            category_name: category.name
          )
        }
      end
    end

    if context === 'neighbourhood_petition'
      CivicallyPetition::Petition.find('place').each do |topic|
        if topic.location && topic.location['geo_location'] && topic.location['geo_location']['osm_id'].to_i === osm_id
          return {
            message: I18n.t('place.validation.petition_exists',
              topic_url: topic.url,
              topic_title: topic.title
            )
          }
        end
      end
    end

    { geo_location: geo_location }
  end
end

DiscourseEvent.on(:custom_wizard_ready) do
  if !CustomWizard::Wizard.find('neighbourhood_petition') || Rails.env.development?
    CustomWizard::Wizard.add_wizard(File.read(File.join(
      Rails.root, 'plugins', 'civically-place', 'config', 'wizards', 'neighbourhood_petition.json'
    )))
  end

  CustomWizard::Field.add_assets('prefilled-composer', 'civically-place', ['components'])

  CustomWizard::Builder.add_step_handler('neighbourhood_petition') do |builder|
    updater = builder.updater

    if builder.updater && builder.updater.step && builder.updater.step.id === 'intro'
      input = builder.updater.fields.to_h
      user = builder.wizard.user

      if builder.submissions.empty?
        builder.submissions.push({})
      end

      builder.submissions.last["location"] = {
        city: user.town.name,
        countrycode: user.town.country.slug
      }

      builder.updater.refresh_required = true
    end

    if builder.updater && builder.updater.step && builder.updater.step.id === 'location'
      input = builder.updater.fields.to_h

      if builder.submissions.empty?
        builder.submissions.push({})
      end

      default_post = I18n.t('neighbourhood_petition.topic.post.default', placeName: input['location']['geo_location']['name'])
      builder.submissions.last["post"] = default_post

      builder.updater.refresh_required = true
    end

    if builder.updater && builder.updater.step && builder.updater.step.id === 'submit'
      updater = builder.updater
      submission = builder.submissions.last || {}
      user = builder.wizard.user

      updater.errors.add(:neighbourhood_petition, I18n.t('neighbourhood_petition.submit.error')) if !submission
      updater.errors.add(:neighbourhood_petition, I18n.t('neighbourhood_petition.location.error')) if !submission['location']
      updater.errors.add(:neighbourhood_petition, I18n.t('neighbourhood_petition.post.error')) if !submission['post']

      unless updater.errors.any?
        result = CivicallyPlace::PlaceManager.create_petition_topic(user,
          geo_location: submission['location']['geo_location'],
          raw: submission['post']
        )

        if result.errors.any?
          updater.errors.add(:neighbourhood_petition, result.errors.full_messages.join("\n"))
        else
          CivicallyChecklist::Checklist.add_item(user,
            id: "pass_petition",
            checked: false,
            checkable: false,
            hidden: false,
            hideable: false,
            active: true,
            title: I18n.t('checklist.place_setup.pass_petition.title'),
            detail: I18n.t('checklist.place_setup.pass_petition.detail',
              petition_url: result.post.url
            )
          )

          user.custom_fields['neighbourhood_petition_id'] = result.post.topic_id
          user.save_custom_fields(true)

          updater.result = { redirect_to: result.post.url }
        end
      end
    end
  end
end

after_initialize do
  ::TopicQuery.public_valid_options.push(:no_definitions, :subtype)

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
    put "add" => "place_manage#add"
    put "user/set" => "place_user#set"
    put "user/set-home" => "place_user#set_home"
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
  load File.expand_path('../jobs/update_place_stats.rb', __FILE__)
  load File.expand_path('../jobs/notify_moderators_of_place_creation_errors.rb', __FILE__)
  load File.expand_path('../lib/place_manager.rb', __FILE__)
  load File.expand_path('../lib/place_badges.rb', __FILE__)
  load File.expand_path('../lib/place_user.rb', __FILE__)
  load File.expand_path('../lib/place_category.rb', __FILE__)
  load File.expand_path('../lib/place_locations.rb', __FILE__)

  add_to_serializer(:basic_category, :topic_id) { object.topic_id }
  add_to_serializer(:basic_category, :is_place) { object.is_place }

  add_to_serializer(:user, :town_category_id) { object.town_category_id }
  add_to_serializer(:user, :neighbourhood_category_id) { object.neighbourhood_category_id }
  add_to_serializer(:user, :neighbourhood_petition_id) { object.neighbourhood_petition_id }
  add_to_serializer(:current_user, :town_category_id) { object.town_category_id }
  add_to_serializer(:current_user, :neighbourhood_category_id) { object.neighbourhood_category_id }
  add_to_serializer(:current_user, :neighbourhood_petition_id) { object.neighbourhood_petition_id }
  add_to_serializer(:admin_user_list, :town_category_id) { object.town_category_id }
  add_to_serializer(:admin_user_list, :neighbourhood_category_id) { object.neighbourhood_category_id }
  add_to_serializer(:admin_user_list, :neighbourhood_petition_id) { object.neighbourhood_petition_id }

  add_to_serializer(:user, :town) { BasicCategorySerializer.new(object.town, scope: scope, root: false) }
  add_to_serializer(:user, :include_town?) { object.town_category_id.present? }
  add_to_serializer(:current_user, :town) { BasicCategorySerializer.new(object.town, scope: scope, root: false) }
  add_to_serializer(:current_user, :include_place?) { object.town_category_id.present? }
  add_to_serializer(:user, :town_joined_at) { object.town_joined_at }
  add_to_serializer(:user, :include_town_joined_at?) { object.town_category_id.present? }
  add_to_serializer(:current_user, :town_joined_at) { object.town_joined_at }
  add_to_serializer(:current_user, :include_town_joined_at?) { object.town_category_id.present? }

  add_to_serializer(:user, :neighbourhood) { BasicCategorySerializer.new(object.neighbourhood, scope: scope, root: false) }
  add_to_serializer(:user, :include_neighbourhood?) { object.neighbourhood_category_id.present? }
  add_to_serializer(:current_user, :neighbourhood) { BasicCategorySerializer.new(object.neighbourhood, scope: scope, root: false) }
  add_to_serializer(:current_user, :include_neighbourhood?) { object.neighbourhood_category_id.present? }
  add_to_serializer(:user, :neighbourhood_joined_at) { object.neighbourhood_joined_at }
  add_to_serializer(:user, :include_neighbourhood_joined_at?) { object.neighbourhood_category_id.present? }
  add_to_serializer(:current_user, :neighbourhood_joined_at) { object.neighbourhood_joined_at }
  add_to_serializer(:current_user, :include_neighbourhood_joined_at?) { object.neighbourhood_category_id.present? }

  add_to_serializer(:user, :place_home) { object.place_home }
  add_to_serializer(:user, :include_place_home?) { object.town_category_id.present? }
  add_to_serializer(:current_user, :place_home) { object.place_home }
  add_to_serializer(:current_user, :include_place_home?) { object.town_category_id.present? }

  add_to_serializer(:user, :town_points) { object.town_points }
  add_to_serializer(:user, :include_town_points?) { object.town_category_id.present? }
  add_to_serializer(:current_user, :town_points) { object.town_points }
  add_to_serializer(:current_user, :include_town_points?) { object.town_category_id.present? }
  add_to_serializer(:user, :neighbourhood_points) { object.neighbourhood_points }
  add_to_serializer(:user, :include_neighbourhood_points?) { object.neighbourhood_category_id.present? }
  add_to_serializer(:current_user, :neighbourhood_points) { object.neighbourhood_points }
  add_to_serializer(:current_user, :include_neighbourhood_points?) { object.neighbourhood_category_id.present? }

  add_to_serializer(:current_user, :added_place_id) { object.added_place_id }
  add_to_serializer(:current_user, :include_added_place_id?) { object.added_place_id.present? }

  self.add_model_callback(User, :before_destroy, prepend: true) do
    if town_category_id = self.town_category_id
      CivicallyPlace::PlaceManager.update_user_count(town_category_id, modifier: -1)
    end

    if neighbourhood_category_id = self.neighbourhood_category_id
      CivicallyPlace::PlaceManager.update_user_count(neighbourhood_category_id, modifier: -1)
    end
  end

  DiscourseEvent.trigger(:place_ready)
end
