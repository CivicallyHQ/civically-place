require_dependency 'badge_grouping'
require_dependency 'badge'

module BadgeGroupingPlaceExtension
  Place = 6
end

class ::BadgeGrouping
  prepend BadgeGroupingPlaceExtension
end

unless ::BadgeGrouping.where(name: 'Place').exists?
  ::BadgeGrouping.all.each do |g|
    g.position = g.position + 1
    g.save
  end

  group = BadgeGrouping.new(id: 6)
  group.name = 'Place'
  group.position = 0
  group.save
end

module BadgePlaceExtension
  Pioneer = 200
  Marshal = 201
  Founder = 202
end

class ::Badge
  prepend BadgePlaceExtension
end

unless Badge.where(name: "Pioneer").exists?
  pioneer = Badge.new(
    id: Badge::Pioneer,
    name: I18n.t('badges.pioneer.name'),
    badge_type_id: BadgeType::Bronze,
    badge_grouping_id: BadgeGrouping::Place,
    default_icon: 'fa-tree',
    allow_title: true,
    multiple_grant: false,
    target_posts: false,
    show_posts: false,
    default_badge_grouping_id: BadgeGrouping::Place,
    auto_revoke: false,
    description: I18n.t('badges.pioneer.description'),
    long_description: I18n.t('badges.pioneer.long_description')
  )
  pioneer.save
end

unless Badge.where(name: "Marshal").exists?
  notable = Badge.new(
    id: Badge::Marshal,
    name: I18n.t('badges.marshal.name'),
    badge_type_id: BadgeType::Silver,
    badge_grouping_id: BadgeGrouping::Place,
    default_icon: 'fa-tree',
    allow_title: true,
    multiple_grant: false,
    target_posts: false,
    show_posts: false,
    default_badge_grouping_id: BadgeGrouping::Place,
    auto_revoke: false,
    description: I18n.t('badges.marshal.description'),
    long_description: I18n.t('badges.marshal.long_description')
  )
  notable.save
end

unless Badge.where(name: "Founder").exists?
  founder = Badge.new(
    id: Badge::Founder,
    name: I18n.t('badges.founder.name'),
    badge_type_id: BadgeType::Gold,
    badge_grouping_id: BadgeGrouping::Place,
    default_icon: 'fa-tree',
    allow_title: true,
    multiple_grant: false,
    target_posts: false,
    show_posts: false,
    default_badge_grouping_id: BadgeGrouping::Place,
    auto_revoke: false,
    description: I18n.t('badges.founder.description'),
    long_description: I18n.t('badges.founder.long_description')
  )
  founder.save
end
