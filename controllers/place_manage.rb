class CivicallyPlace::PlaceManageController < ::ApplicationController
  requires_login

  def add
    params.require(:geo_location)

    user = current_user

    result = CivicallyPlace::PlaceManager.create(params[:geo_location], user)

    if result[:category_id]
      user_result = User.update_place_category_id(user, result[:category_id])

      if user_result[:error]
        render json: { error: user_result[:error] }
      else
        route_to = Category.find(user_result[:place_category_id]).url
        render json: success_json.merge(user_result.merge(route_to: route_to))
      end
    else
      message = result[:error] ? result[:error] : I18n.t('place.add.error.failed')
      render json: failed_json.merge(message: message)
    end
  end
end
