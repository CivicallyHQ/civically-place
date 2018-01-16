class CivicallyPlace::UserPlaceController < ::ApplicationController
  def index
    render nothing: true
  end

  def set_place
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
      render json: success_json.merge(result)
    end
  end
end
