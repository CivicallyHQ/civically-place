module Jobs
  class NotifyModeratorsOfRegionNeighbourhoodConflict < Jobs::Base
    def execute(args)
      category = Category.find(args[:category_id])
      region = CivicallyPlace::Region.find(args[:region_id])
      region_place = Category.find(region[:category_id])
      site_moderators.each do |user|
        if user
          SystemMessage.create_from_system_user(user,
            :region_neighbourhood_conflict,
              neighbourhood: category.name,
              neighbourhood_path: category.topic_url,
              region: region[:name],
              region_place: region_place.name,
              region_place_path: region_place.topic_id
          )
        end
      end
    end

    def site_moderators
      User.where(moderator: true)
        .human_users
        .select { |u| u.admin || u.custom_fields['moderator_category_id'].blank? }
    end
  end
end
