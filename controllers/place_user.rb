class CivicallyPlace::PlaceUserController < ::ApplicationController
  requires_login

  def index
    render nothing: true
  end

  def set
    params.require(:category_id)
    params.permit(:user_id)

    user = current_user
    force = false

    if params[:user_id]
      if current_user.admin?
        user = User.find(params[:user_id])
        force = true
      else
        raise Discourse::InvalidAccess.new
      end
    end

    result = User.update_place_category_id(user, params[:category_id].to_i, force)

    if result[:error]
      render json: { error: result[:error] }
    else
      route_to = Category.find(user_result[:place_category_id]).url
      render json: success_json.merge(result.merge(route_to: route_to))
    end
  end
end
