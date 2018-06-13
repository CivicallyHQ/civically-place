class CivicallyPlace::PlaceUserController < ::ApplicationController
  requires_login

  def index
    render nothing: true
  end

  def set
    params.require(:category_id)
    params.require(:type)

    user = current_user
    type = set_params[:type]
    category_id = set_params[:category_id].to_i
    force = false

    if set_params[:user_id]
      if current_user.admin?
        user = User.find(set_params[:user_id])
        force = true
      else
        raise Discourse::InvalidAccess.new
      end
    end

    result = User.send("update_#{type}_category_id", user, category_id, force)

    if result[:error]
      render json: { error: result[:error] }
    else
      route_to = Category.find(result["#{type}_category_id".to_sym]).url
      render json: success_json.merge(result.merge(route_to: route_to))
    end
  end

  def set_home
    params.require(:place_home)

    user = current_user

    user.custom_fields['place_home'] = params[:place_home]

    if user.save_custom_fields(true)
      render json: success_json.merge(place_home: user.place_home)
    else
      render json: failed_json
    end
  end

  private

  def set_params
    params.permit(:category_id, :type, :user_id)
  end
end
