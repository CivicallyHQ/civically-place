module Jobs
  class NotifyModeratorsOfPlaceCreationErrors < Jobs::Base
    def execute(args)
      category = Category.find(args[:category_id])
      site_moderators.each do |user|
        if user
          SystemMessage.create_from_system_user(user,
            :place_creation_issues,
              place: category.name,
              path: category.topic_url,
              errors: args[:error_messages]
          )
        end
      end
    end

    def site_moderators
      User.where(moderator: true)
        .human_users
        .select { |u| u.custom_fields['moderator_category_id'].blank? }
    end
  end
end
