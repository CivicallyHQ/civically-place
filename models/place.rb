class CivicallyPlace::Place
  include ActiveModel::SerializerSupport

  attr_accessor :name,
                :can_join,
                :member,
                :members,
                :joined_at,
                :user_count,
                :user_count_min,
                :category,
                :has_moderator_election,
                :moderator_election_url

  def initialize(category_id, user = nil)
    @category = Category.find(category_id)
    @user = user
  end

  def name
    @category.topic.title
  end

  def can_join
    !!@category.custom_fields['place_can_join']
  end

  def user_count
    @category.custom_fields['place_user_count'] || 0
  end

  def user_count_min
    if @category.custom_fields['place_user_count_min'].present?
      @category.custom_fields['place_user_count_min']
    elsif type
      SiteSetting.send("place_#{type}_user_count_min")
    else
      nil
    end
  end

  def type
    if @category.location && @category.location['geo_location']
      @category.location['geo_location']['type']
    else
      nil
    end
  end

  def member
    @user && @user.place_category_id.to_i === @category.id.to_i
  end

  def joined_at
    return nil if !member
    UserHistory.where(
      action: UserHistory.actions[:place],
      acting_user_id: @user.id
    ).order(:created_at).last[:created_at].to_date
  end

  def moderator_election_topics
    DiscourseElections::ElectionCategory.topics(@category.id, roles: 'moderator')
  end

  def moderator_election_url
    if moderator_election_topics.present?
      moderator_election_topics.first.url
    else
      nil
    end
  end

  def has_moderator_election
    moderator_election_topics.any?
  end

  def members
    CivicallyPlace::Place.members(@category.id)
  end

  def self.members(category_id)
    User.where("id in (
      SELECT user_id FROM user_custom_fields WHERE name = 'place_category_id' AND value = ?
    )", category_id.to_s)
  end

  def self.create(topic_id, forced)
    topic = Topic.find(topic_id)
    if !forced && topic.petition_supporters.length < topic.petition_vote_threshold
      return { error: I18n.t('place.topic.error.insufficient_supporters') }
    end

    result = CivicallyPlace::PlaceManager.create_place_category(topic.id)

    return { error: result[:error] } if result[:error]

    CivicallyPlace::PlaceManager.setup_place(result[:category_id])

    result
  end
end
