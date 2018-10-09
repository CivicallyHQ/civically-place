class CivicallyPlace::Region
  def self.find(region_id)
    if region = PluginStore.get('region', region_id)
      region = ::JSON.parse(region)
      region.merge(id: region_id).symbolize_keys
    end
  end

  def self.update(region_id, updates)
    existing = CivicallyPlace::Region.find(region_id)
    updated = existing.merge(update)
    PluginStore.set('region', region_id, ::JSON.generate(updated))
  end

  def self.create(region)
    region_id = region[:geo_location][:osm_id].present? ? region[:geo_location][:osm_id] : SecureRandom.hex(7)
    PluginStore.set('region', region_id, ::JSON.generate(region))
    region_id
  end

  def self.remove(category_id, region_id)
    PluginStoreRow.where(plugin_name: 'region', key: region_id).delete_all
    CategoryCustomField.where(category_id: category_id, name: 'region_id', value: region_id).delete_all
  end
end
