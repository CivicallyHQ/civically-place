class CivicallyPlace::PlaceManageController < ::ApplicationController
  requires_login

  def add
    params.require(:geo_location)
    opts = params.permit(geo_location: {}).to_h

    user = current_user

    result = CivicallyPlace::PlaceManager.create(opts[:geo_location], user)

    if result[:category_id]
      user_result = User.update_town_category_id(user, result[:category_id])

      if user_result[:error]
        render json: { error: user_result[:error] }
      else
        route_to = Category.find(user_result[:town_category_id]).url
        render json: success_json.merge(user_result.merge(route_to: route_to))
      end
    else
      message = result[:error] ? result[:error] : I18n.t('place.add.error.failed')
      render json: failed_json.merge(message: message)
    end
  end

  def list
    params.require(:petition_id)

    topics = Topic.where(subtype: 'petition')
      .joins("JOIN topic_custom_fields ON topic_custom_fields.topic_id = topics.id")
      .where("topic_custom_fields.name = 'petition_id' AND value = ?", params[:petition_id])
      .order(:created_at)

    render_serialized(topics, CivicallyPetition::PetitionListSerializer)
  end
end
