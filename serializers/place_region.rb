class CivicallyPlace::RegionSerializer < ::ApplicationSerializer
  attributes :id, :name

  def id
    object[:id]
  end

  def name
    object[:name]
  end
end
