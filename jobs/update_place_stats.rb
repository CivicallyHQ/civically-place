module Jobs
  class UpdatePlaceStats < Jobs::Scheduled
    every 1.day

    def execute(args)
      CivicallyPlace::Place.all_places.each do |place|
        CivicallyPlace::PlaceManager.update_user_count(place.id,
          user_count: CivicallyPlace::Place.members(place.id).count
        )
      end
    end
  end
end
