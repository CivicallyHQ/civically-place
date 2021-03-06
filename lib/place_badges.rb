## See also civically-site/db/fixtures/007_civically_badges.rb

module BadgeGroupingPlaceExtension
  Place = 10
end

require_dependency 'badge_grouping'
class ::BadgeGrouping
  prepend BadgeGroupingPlaceExtension
end

module BadgePlaceExtension
  Local = 300
  Supporter = 301
  Founder = 302
end

require_dependency 'badge'
class ::Badge
  prepend BadgePlaceExtension
end
