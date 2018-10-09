class CivicallyPlace::PlaceAdminController < ::ApplicationController
  requires_login
  before_action :ensure_staff

  def add_region
    region = params.require(:region).permit(:name, geo_location: {}).to_h
    place = CivicallyPlace::Place.find(params[:category_id])

    region[:category_id] = place.id
    region[:hide_marker] = true

    region_id = CivicallyPlace::Region.create(region)

    region_ids = place.region_ids
    region_ids.push(region_id)

    place.custom_fields['region_id'] = region_ids
    place.save_custom_fields(true)

    if region = CivicallyPlace::Region.find(region_id)
      render json: success_json.merge(region: region)
    else
      render json: failed_json
    end
  end

  def remove_region
    params.require(:region_id)

    if CivicallyPlace::Region.remove(params[:category_id], params[:region_id])
      render json: success_json.merge(region_id: params[:region_id])
    else
      render json: failed_json
    end
  end
end
