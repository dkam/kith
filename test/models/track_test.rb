require "test_helper"

# Every coordinate in here is on the equator near the prime meridian, in open
# ocean, where a degree of longitude is exactly R_earth × π / 180 metres along
# a great circle — so every expected distance can be worked out by hand.
class TrackTest < ActiveSupport::TestCase
  # 0.001° of longitude on the equator.
  STEP_M = Track::Geo::EARTH_RADIUS_M * 0.001 * Math::PI / 180 # ≈ 111.195 m

  def point(lon, time: nil, ele: nil, lat: 0.0)
    Track::Point.new(lon:, lat:, ele:, time:)
  end

  test "positions are rounded to 6 decimal places as they are read, so what is trimmed is what is stored" do
    track = Track.new([ [ point(0.12345674999, lat: -0.9876545001, ele: 10.04999), point(0.001, ele: 11.0) ] ])

    first = track.points.first
    assert_equal 0.123457, first.lon
    assert_equal(-0.987655, first.lat)
    assert_equal 10.0, first.ele
  end

  test "an empty track is empty" do
    assert Track.new([]).empty?
    assert Track.new([ [] ]).empty?
    assert_not Track.new([ [ point(0.0), point(0.001) ] ]).empty?
  end

  test "distance is the haversine sum within each segment, and never across a gap" do
    track = Track.new([
      [ point(0.000), point(0.001), point(0.002) ],
      # 8 steps further on: a gap that must not be counted
      [ point(0.010), point(0.011) ]
    ])

    assert_in_delta 3 * STEP_M, track.distance_m, 0.1
  end

  test "moving time counts intervals at walking pace or faster, and not standing still" do
    track = Track.new([
      [
        point(0.000, time: 0),
        point(0.001, time: 20),   # 5.6 m/s: moving
        point(0.002, time: 40),   # moving
        point(0.002, time: 100),  # stood still for a minute
        point(0.002, time: 160),  # and another
        point(0.0020001, time: 200) # 0.01 m in 40 s: drifting, not moving
      ],
      [ point(0.010, time: 1000), point(0.011, time: 1010) ] # 11 m/s
    ])

    assert_equal 50, track.moving_time_s
  end

  test "half a metre a second is the line between moving and not" do
    # One step is 111.195 m: in 222 s that is 0.5009 m/s, in 223 s 0.4986 m/s.
    assert_equal 222, Track.new([ [ point(0.0, time: 0), point(0.001, time: 222) ] ]).moving_time_s
    assert_equal 0, Track.new([ [ point(0.0, time: 0), point(0.001, time: 223) ] ]).moving_time_s
  end

  test "climb ignores GPS altitude jitter under 3 m" do
    elevations = [ 100.0, 101.5, 99.8, 101.2, 100.4, 102.7, 100.1 ]
    track = Track.new([ elevations.each_with_index.map { |ele, i| point(i * 0.001, ele:) } ])

    assert_equal 0.0, track.elevation_gain_m
  end

  test "climb counts a rise from the last low once it reaches 3 m, and all of it after that" do
    # Low of 99.8, then up to 110: 10.2 m. A 2 m dip on the way up does not end
    # the climb; the rise past the old peak continues it.
    elevations = [ 100.0, 99.8, 101.0, 103.0, 106.0, 104.0, 108.0, 110.0, 109.0 ]
    track = Track.new([ elevations.each_with_index.map { |ele, i| point(i * 0.001, ele:) } ])

    assert_in_delta 10.2, track.elevation_gain_m, 0.001
  end

  test "climb is counted within each segment, never across a gap" do
    track = Track.new([
      [ point(0.000, ele: 100.0), point(0.001, ele: 101.0) ],
      [ point(0.010, ele: 120.0), point(0.011, ele: 121.0) ]
    ])

    assert_equal 0.0, track.elevation_gain_m
  end

  test "a track with no times has no moving time, and one with no elevation no climb" do
    track = Track.new([ [ point(0.000), point(0.001) ] ])

    assert_nil track.moving_time_s
    assert_nil track.elevation_gain_m
  end

  test "elevation and times are all or nothing: a track never mixes them" do
    track = Track.new([ [ point(0.000, ele: 5.0, time: 0), point(0.001, time: 10), point(0.002, ele: 7.0) ] ])

    assert_not track.elevation?
    assert_not track.timed?
    assert track.points.all? { |p| p.ele.nil? && p.time.nil? }
  end

  test "to_geojson writes a MultiLineString with times parallel to it, relative to each segment" do
    track = Track.new([
      [ point(0.0000001, time: 1_789_000_000, ele: 12.34), point(0.001, time: 1_789_000_010.6, ele: 13.0) ],
      [ point(0.010, time: 1_789_000_500, ele: 14.0), point(0.011, time: 1_789_000_520, ele: 15.0) ]
    ])

    json = JSON.parse(track.to_geojson)

    assert_equal "Feature", json["type"]
    assert_equal "MultiLineString", json.dig("geometry", "type")
    assert_equal [ [ [ 0.0, 0.0, 12.3 ], [ 0.001, 0.0, 13.0 ] ], [ [ 0.01, 0.0, 14.0 ], [ 0.011, 0.0, 15.0 ] ] ],
      json.dig("geometry", "coordinates")
    assert_equal [ [ 0, 11 ], [ 0, 20 ] ], json.dig("properties", "times")
  end

  test "to_geojson leaves elevation out of every position, and times out altogether, when there are none" do
    json = JSON.parse(Track.new([ [ point(0.000), point(0.001) ] ]).to_geojson)

    assert_equal [ [ [ 0.0, 0.0 ], [ 0.001, 0.0 ] ] ], json.dig("geometry", "coordinates")
    assert_equal({}, json["properties"])
  end

  test "from_geojson reads back what to_geojson wrote" do
    track = Track.new([
      [ point(0.0, time: 0, ele: 1.0), point(0.001, time: 10, ele: 2.0), point(0.002, time: 25, ele: 2.5) ],
      [ point(0.010, time: 0, ele: 9.0), point(0.011, time: 30, ele: 8.0) ]
    ])

    again = Track.from_geojson(track.to_geojson)

    assert_equal track.segments, again.segments
    assert_equal track.to_geojson, again.to_geojson
  end

  # A GPX can hold a <trkseg> of one point, and a real export does. A
  # MultiLineString cannot: each line needs two positions. But the point is
  # where the member was — press start, auto-pause, ride on — and a first or
  # last point is where a trim centres a circle, so it is kept, in its
  # neighbour, and whatever is written reads back.
  test "a segment of one point joins the next one, or the one before if it is last, and what it writes reads back" do
    a, b, c = point(0.0, time: 0), point(0.010, time: 10), point(0.011, time: 20)
    d, e, f = point(0.02, time: 0), point(0.021, time: 10), point(0.03, time: 20)
    lons = ->(track) { track.segments.map { |segment| segment.map(&:lon) } }

    track = Track.new([ [ a ], [ b, c ], [ d ], [ e ], [ f ] ])
    assert_equal [ [ 0.0, 0.010, 0.011 ], [ 0.02, 0.021, 0.03 ] ], lons[track]
    assert_equal track, Track.from_geojson(track.to_geojson)

    assert_equal [ [ 0.0, 0.010 ] ], lons[Track.new([ [ a ], [ b ] ])]
    assert_equal [ [ 0.010, 0.011, 0.02 ] ], lons[Track.new([ [ b, c ], [ d ] ])]
    assert Track.new([ [ a ] ]).empty?
    assert Track.new([ [ a ], [] ]).empty?
  end

  test "from_geojson refuses anything that is not the stored shape" do
    [
      "not json",
      { type: "FeatureCollection" }.to_json,
      { type: "Feature", geometry: { type: "LineString", coordinates: [ [ 0, 0 ], [ 1, 1 ] ] } }.to_json,
      { type: "Feature", geometry: { type: "MultiLineString", coordinates: [ [ [ 0, 0 ] ] ] } }.to_json,
      { type: "Feature", geometry: { type: "MultiLineString", coordinates: [ [ [ 0, "0" ], [ 1, 1 ] ] ] } }.to_json,
      { type: "Feature", geometry: { type: "MultiLineString", coordinates: [ [ [ 0, 95 ], [ 1, 1 ] ] ] } }.to_json,
      { type: "Feature", geometry: { type: "MultiLineString", coordinates: [ [ [ 0, 0 ], [ 1, 1 ] ] ] },
        properties: { times: [ [ 0 ] ] } }.to_json
    ].each do |json|
      assert_raises(Track::Malformed, json) { Track.from_geojson(json) }
    end
  end

  test "a malformed track's message never carries a coordinate" do
    error = assert_raises(Track::Malformed) do
      Track.from_geojson({ type: "Feature", geometry: { type: "MultiLineString",
        coordinates: [ [ [ 12.345678, 95.123456 ], [ 1, 1 ] ] ] } }.to_json)
    end

    assert_no_match(/\d+\.\d+/, error.message)
  end
end
