class CivicallyPlace::PlaceUserSerializer < CivicallyPlace::PlaceSerializer
  attributes :member,
             :joined_at,
             :user_count,
             :user_count_min
end
