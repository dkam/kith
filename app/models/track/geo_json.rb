# The stored form of a track, and a contract: the phone apps write and read the
# same thing.
#
#   { "type": "Feature",
#     "geometry": { "type": "MultiLineString",
#                   "coordinates": [[[lon, lat, ele], ...], ...] },
#     "properties": { "times": [[0, 1, 2, ...], ...] } }
#
# One inner array per segment, and `times` parallel to `coordinates`. Times
# are whole seconds since that segment's first point, which is always 0, and
# never absolute: an absolute first time against the workout's occurred_at
# would time the trimmed start, and absolute times either side of a gap would
# time the crossing of a zone — and a time is a distance. Elevation is left out
# of every position when there is none, and `times` is left out altogether.
#
# Errors name the part that is wrong and never the value in it: the value is a
# coordinate.
module Track::GeoJson
  module_function

  def write(track)
    {
      type: "Feature",
      geometry: {
        type: "MultiLineString",
        coordinates: track.segments.map { |segment|
          segment.map { |point| [ point.lon, point.lat, point.ele ].compact }
        }
      },
      properties: track.timed? ? { times: track.segments.map { |segment| relative_times(segment) } } : {}
    }.to_json
  end

  def read(json)
    feature = JSON.parse(json)
    malformed("not a GeoJSON Feature") unless feature.is_a?(Hash) && feature["type"] == "Feature"

    geometry = feature["geometry"]
    malformed("geometry is not a MultiLineString") unless geometry.is_a?(Hash) && geometry["type"] == "MultiLineString"

    coordinates = geometry["coordinates"]
    malformed("coordinates are not a list of segments") unless coordinates.is_a?(Array) && coordinates.all?(Array)

    times = (feature["properties"] || {})["times"]

    Track.new(coordinates.each_with_index.map { |segment, s| read_segment(segment, times && times[s], s) })
  rescue JSON::ParserError
    malformed("not JSON")
  end

  def read_segment(positions, times, index)
    malformed("segment #{index} has fewer than two points") if positions.size < 2
    unless times.nil? || (times.is_a?(Array) && times.size == positions.size && times.all?(Integer))
      malformed("segment #{index} has times that do not match its points")
    end

    positions.each_with_index.map do |position, i|
      lon, lat, ele = position
      unless position.is_a?(Array) && position.size.in?(2..3) && position.all?(Numeric) &&
          lat.between?(-90, 90) && lon.between?(-180, 180)
        malformed("segment #{index} point #{i} is not a position")
      end

      Track::Point.new(lon:, lat:, ele:, time: times&.at(i))
    end
  end

  def relative_times(segment)
    start = segment.first.time
    segment.map { |point| (point.time - start).round }
  end

  def malformed(what)
    raise Track::Malformed, what
  end
end
