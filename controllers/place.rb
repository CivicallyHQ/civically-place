require_dependency 'topic_list_responder'

class CivicallyPlace::PlaceController < ::ApplicationController
  include TopicListResponder

  def index
    render nothing: true
  end

  def list
    params.permit(:opts)

    categories = Category.joins("INNER JOIN category_custom_fields
                                ON category_custom_fields.category_id = categories.id
                                AND category_custom_fields.name = 'place'
                                AND category_custom_fields.value::boolean IS TRUE")

    if params[:opts] && params[:opts][:can_join]
      categories = categories.where("categories.id in (
        SELECT category_id FROM category_custom_fields
        WHERE name = 'place_can_join'
        AND value::boolean IS TRUE
      )")
    end

    places = categories.select('id', 'name') || []

    render json: { places: places }
  end

  def get
    params.require(:category_id)

    place = CivicallyPlace::Place.new(params[:category_id], current_user)

    if place.can_join
      render_serialized(place, CivicallyPlace::PlaceUserSerializer)
    else
      render_serialized(place, CivicallyPlace::PlaceSerializer)
    end
  end

  def groups
    groups = Group.visible_groups(current_user)
      .where("groups.id in (
        SELECT group_id FROM group_custom_fields WHERE name = 'category_id' AND value = ?
      )", params[:category_id].to_s)
      .order(:created_at)
      .limit(4)

    render_serialized(groups, BasicGroupSerializer)
  end

  def events
    params.require(:category_id)

    user = current_user
    list_opts = {
      category: params[:category_id],
      limit: 4
    }

    list = TopicQuery.new(user, list_opts).list_agenda

    respond_with_list(list)
  end

  def petitions
    params.require(:category_id)

    topics = Topic.where(category_id: params[:category_id])
      .joins("JOIN topic_custom_fields ON topic_custom_fields.topic_id = topics.id
              AND topic_custom_fields.name = 'petition'
              AND topic_custom_fields.value::boolean IS TRUE")
      .order(:created_at)
      .limit(4)

    render_serialized(topics, CivicallyPetition::PetitionListSerializer)
  end

  def ratings
    params.require(:category_id)

    topics = Topic.where(category_id: params[:category_id], subtype: 'rating')
      .order(:created_at)
      .limit(4)

    render_serialized(topics, DiscourseRatings::RatingListSerializer)
  end
end
