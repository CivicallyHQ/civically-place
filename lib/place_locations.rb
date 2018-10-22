## Place Locations ##
# There are two types of places:
#   - Contiguous Urban Areas ('town' for short). This is any seperate* city, town or village.
#   - Neighbourhoods. Any area that contains a local community, or has a distinct character,
#     and can support an online community of 100 or more members.
#
# * If a town, village or hamlet is part of a city, it is treated as a neighbourhood.
##

PlaceLocation = Struct.new(
  :osm_id, # OpenStreeMap Id
  :boundingbox, # Bounding box in form: [["southwest"]["lat"],["northeast"]["lat"], ["southwest"]["lon"], ["northeast"]["lon"]]
  :longitude,
  :latitude,
  :postal_code,
  :country_code, # ISO Alpha-2 country code
  :international_code, # E.g. 'eu' for European Union
  :country,
  :state,
  :district,
  :city,
  :town,
  :village,
  :neighbourhood,
  :address, # Full name / address
  :type, # city, town, village or neighbourhood
  :name # Short name of place
)

class CivicallyPlace::Locations
  def self.filter(locations, options)
    locations.select do |location|
      self.send("filter_#{options[:provider]}", location.data, options)
    end
  end

  def self.filter_nominatim(location, options)
    if location['class'] === 'place'
      return false unless SiteSetting.send("place_#{options[:place_type]}_types").split('|').include?(location['type'])

      if options[:place_type] === 'town'
        return location['type'] === 'city' || location['address']['city'].blank?
      elsif options[:place_type] === 'neighbourhood'
        if SiteSetting.place_town_types.include?(location['type'])
          location['address']['city'].present?
        else
          true
        end
      else
        false
      end
    elsif options[:place_type] === 'neighbourhood'
      location['class'] === 'boundary' &&
      location['type'] === 'administrative' &&
      location['address']['suburb'].present?
    else
      false
    end
  end

  def self.filter_opencagedata(location, options)
    components = location['components']

    return true if options[:place_type] === 'region'

    return false unless SiteSetting.send("place_#{options[:place_type]}_types").split('|').include?(components['_type'])

    if options[:place_type] === 'town'
      components['city'].present? && components['town'].blank? && components['village'].blank? ||
      components['city'].blank? && components['town'].present? && components['village'].blank? ||
      components['city'].blank? && components['town'].blank? && components['village'].present?
    elsif options[:place_type] === 'neighbourhood'
      (components['_type'] === 'neighbourhood' || components['_type'] === 'county') ||
      (components['city'].present? && (components['town'].present? || components['village'].present?))
    else
      false
    end
  end

  def self.is_duplicate(location_list, location)
    location_list.any? do |l|
      l[:type] == location[:type] &&
      l[:country_code] == location[:country_code] &&
      l[:state] == location[:state] &&
      l[:district] == location[:district] &&
      (l[:city] == location[:city] ||
       l[:town] == location[:town] ||
       l[:village] == location[:village] ||
       l[:neighbourhood] == location[:neighbourhood])
    end
  end

  def self.format(locations, options)
    formatted_locations = []

    locations.each do |result|
      location = result.data

      location = self.send("format_#{options[:provider]}", location, options)

      location[:country] = Locations::Country.codes.select do |c|
        c[:code] == location[:country_code]
      end.first[:name]

      unless self.is_duplicate(formatted_locations, location)
        formatted_locations.push(PlaceLocation.new(*location.values_at(*PlaceLocation.members)))
      end
    end

    formatted_locations
  end

  def self.format_opencagedata(location, options)
    annotations = location['annotations']
    bounds = location["bounds"]
    geometry = location["geometry"]
    components = location["components"]
    type = components["_type"]

    formatted = {
      osm_id: annotations['OSM']['edit_url'][/(?<=\=)(\d+)(?=#map)/], # Currently the only way to get the osm_id from opencagedata results is by parsing the edit_url
      boundingbox: [
        bounds["southwest"]["lat"],
        bounds["northeast"]["lat"],
        bounds["southwest"]["lng"],
        bounds["northeast"]["lng"]
      ],
      latitude: geometry["lat"],
      longitude: geometry["lng"],
      postal_code: components["postcode"],
      country_code: components["country_code"],
      address: location["formatted"]
    }

    if components['political_union']
      formatted[:international_code] = 'eu' if components['political_union'] == 'European Union'
    end

    formatted[:state] = components['state'] if components['state']

    if components['state_district'] || components['county'] || components['region']
      formatted[:district] = components['state_district'] || components['county'] || components['region']
    end

    ## Opencagedata seems to list some towns and villages as 'cities'
    if type === 'city' || type === 'town' || type === 'village'
      formatted[:type] = 'city' if components['city'].present?
      formatted[:type] = 'town' if components['town'].present?
      formatted[:type] = 'village' if components['village'].present?
      formatted[:name] = components[formatted[:type]]
    end

    if type === 'neighbourhood' || type === 'county'
      formatted[:type] = 'neighbourhood'

      if components[formatted[:type]]
        formatted[:name] = components[formatted[:type]]
        formatted[:suburb] = components['suburb'] if components['suburb'].present?
      elsif components['suburb'].present?
        formatted[:name] = components['suburb']
      elsif components['county'].present?
        formatted[:name] = components['county']
      end

      ## Default is the city used in the request
      formatted[:city] = options[:request]['city'] if options[:request]['city'].present?
      formatted[:city] = components['city'] if components['city'].present?
      formatted[:town] = components['town'] if components['town'].present?
      formatted[:village] = components['village'] if components['village'].present?
    end

    formatted
  end

  def self.format_nominatim(location, options)
    address = location['address']

    formatted = {
      osm_id: location['osm_id'],
      boundingbox: location['boundingbox'],
      latitude: location['lat'],
      longitude: location['lon'],
      postal_code: address['postcode'],
      country_code: address['country_code'],
      address: location['display_name']
    }

    if location['class'] === 'place'
      formatted[:type] = location['type']
      formatted[:name] = address[location['type']]
    end

    formatted[:state] = address['state'] if address['state']

    if address['state_district'] || address['county'] || address['region']
      formatted[:district] = address['state_district'] || address['county'] || address['region']
    end

    if options[:place_type] === 'neighbourhood' && location['class'] === 'boundary'
      formatted[:type] = 'neighbourhood'
      formatted[:name] = address['suburb']
    end

    if options[:place_type] === 'neighbourhood'
      ## Default is the city used in the request
      formatted[:city] = options[:request]['city'] if options[:request]['city'].present?
      formatted[:city] = address['city'] if location['city'].present?
      formatted[:town] = address['town'] if location['town'].present?
      formatted[:village] = address['village'] if location['village'].present?
    end

    formatted
  end
end
