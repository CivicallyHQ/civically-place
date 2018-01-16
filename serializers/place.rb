class CivicallyPlace::PlaceSerializer < ::ApplicationSerializer
  attributes :can_join, :moderator_election_url, :category

  def category
    BasicCategorySerializer.new(object.category, scope: scope, root: false).as_json
  end
end
