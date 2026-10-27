require "test_helper"

# The trim is the privacy model for a ride, and the two attacks it answers are
# both tested here as attacks: an off-centre circle whose cut points do not
# fit a circle around home, and nothing about the removed part surviving to be
# measured. Every coordinate is in open ocean on the equator.
class Track::TrimTest < ActiveSupport::TestCase
  FIXTURES = Rails.root.join("test/fixtures/files/trim")

  # A straight ride from `from` on `bearing`, a point every `every_m` metres.
  def ride(length_m:, bearing: 90.0, from: [ 0.0, 0.0 ], every_m: 10.0, start_time: 1_790_000_000)
    lat, lon = from
    points = (0..(length_m / every_m)).map do |i|
      plat, plon = Track::Geo.destination(lat, lon, bearing, i * every_m)
      Track::Point.new(lon: plon, lat: plat, ele: nil, time: start_time + i * 3)
    end

    Track.new([ points ])
  end

  def trim(radius_m: 500, bearing_deg: 90.0, offset_m: 250.0)
    Track::Trim.new(radius_m:, bearing_deg:, offset_m:)
  end

  def metres(point, lat, lon) = Track::Geo.distance_m(point.lat, point.lon, lat, lon)

  def assert_nothing_within(track, metres_of:, lat:, lon:)
    near = track.points.count { |point| metres(point, lat, lon) < metres_of }
    assert_equal 0, near, "#{near} points survived within #{metres_of} m"
  end

  # --- The fixtures, answered by generate.py ---------------------------------

  Dir[FIXTURES.join("*.json")].sort.each do |path|
    name = File.basename(path, ".json")

    test "shared fixture: #{name}" do
      fixture = JSON.parse(File.read(path))
      zones = fixture["zones"].map { |zone| Track::Zone.new(**zone.symbolize_keys) }

      trimmed = Track.from_geojson(fixture["input"].to_json).trim(Track::Trim.new(**fixture["trim"].symbolize_keys), zones:)

      if fixture["expected"].nil?
        assert trimmed.empty?, fixture["description"]
      else
        assert_same_geojson fixture["expected"], JSON.parse(trimmed.to_geojson), fixture["description"]
      end
    end
  end

  test "the shared fixtures are all there" do
    assert_operator Dir[FIXTURES.join("*.json")].size, :>=, 9
  end

  # --- The rules, one at a time ----------------------------------------------

  test "points near the start and the end are dropped" do
    trimmed = ride(length_m: 5_000).trim(trim)

    assert_not trimmed.empty?
    assert_nothing_within trimmed, metres_of: 500, lat: 0.0, lon: 0.0
    end_lat, end_lon = Track::Geo.destination(0.0, 0.0, 90.0, 5_000)
    assert_nothing_within trimmed, metres_of: 500, lat: end_lat, lon: end_lon
  end

  test "a pass by the start halfway round is cut out, and leaves a gap rather than a line" do
    out = ride(length_m: 3_000, bearing: 90.0).points
    back = ride(length_m: 6_000, bearing: 270.0, from: [ out.last.lat, out.last.lon ], start_time: 1_790_001_000).points
    trimmed = Track.new([ out + back ]).trim(trim)

    assert_equal 2, trimmed.segments.size
    assert_nothing_within trimmed, metres_of: 500, lat: 0.0, lon: 0.0
  end

  test "a privacy zone mid-ride splits the segment, and does not join across it" do
    # Offset north, off the line of the ride, so each circle crosses it
    # √(R² + 2R|o|) either side of its point: 707.1 m for the ends, 489.9 m for
    # the zone. That leaves 710–2510 m and 3490–5290 m, no boundary near a point.
    zone = Track::Zone.new(lat: 0.0, lon: Track::Geo.destination(0.0, 0.0, 90.0, 3_000).last, radius_m: 300)
    trimmed = ride(length_m: 6_000).trim(trim(bearing_deg: 0.0), zones: [ zone ])

    assert_equal [ 181, 181 ], trimmed.segments.map(&:size)
    assert_nothing_within trimmed, metres_of: 300, lat: zone.lat, lon: zone.lon
    # Joined across the zone, it would be 4580 m.
    assert_in_delta 3_600.0, trimmed.distance_m, 0.2, "the distance is the two pieces, not a line across the zone"
  end

  test "a ride entirely inside the radius leaves nothing" do
    assert ride(length_m: 300).trim(trim).empty?
  end

  test "an indoor ride with no positions has no track to trim" do
    assert Track.new([]).trim(trim).empty?
  end

  test "a lone point left between two removed stretches is dropped" do
    # A point every 100 m for 3.5 km, offset north. Two zones of 200 m, at 1300
    # and 2100 m, each cross the line 374.2 m either side, so only the point at
    # 1700 m survives between them, alone. The ends leave 800–900 m and
    # 2500–2700 m.
    zones = [ 1_300, 2_100 ].map { |m|
      Track::Zone.new(lat: 0.0, lon: Track::Geo.destination(0.0, 0.0, 90.0, m).last, radius_m: 200)
    }
    trimmed = ride(length_m: 3_500, every_m: 100.0).trim(trim(bearing_deg: 0.0), zones:)

    assert_equal [ 2, 3 ], trimmed.segments.map(&:size)
  end

  test "a point exactly on a circle's boundary survives: the test is strictly inside" do
    point = Track::Point.new(lon: 0.004, lat: 0.003, ele: nil, time: nil)
    radius = Track::Geo.distance_m(0.0, 0.0, point.lat, point.lon)

    assert_not Track::Trim::Circle.new(lat: 0.0, lon: 0.0, radius_m: radius).cover?(point)
    assert Track::Trim::Circle.new(lat: 0.0, lon: 0.0, radius_m: radius.next_float).cover?(point)
  end

  test "a bigger radius cuts more" do
    track = ride(length_m: 5_000)
    trimmed = track.trim(trim(radius_m: 800))

    assert_nothing_within trimmed, metres_of: 800, lat: 0.0, lon: 0.0
    assert_operator trimmed.points.size, :<, track.trim(trim).points.size
  end

  # --- The guarantee, whatever the offset -------------------------------------

  test "nothing within R of the start, the end or a zone survives, for any offset" do
    zone = Track::Zone.new(lat: 0.0, lon: Track::Geo.destination(0.0, 0.0, 90.0, 2_000).last, radius_m: 250)
    out = ride(length_m: 4_000, bearing: 90.0).points
    back = ride(length_m: 6_000, bearing: 270.0, from: [ out.last.lat, out.last.lon ], every_m: 7.0).points
    track = Track.new([ out + back ])
    last = track.points.last

    [ 0.0, 90.0, 180.0, 270.0 ].product([ 125.0, 250.0 ]).each do |bearing_deg, offset_m|
      trimmed = track.trim(trim(bearing_deg:, offset_m:), zones: [ zone ])

      assert_not trimmed.empty?
      assert_nothing_within trimmed, metres_of: 500, lat: 0.0, lon: 0.0
      assert_nothing_within trimmed, metres_of: 500, lat: last.lat, lon: last.lon
      assert_nothing_within trimmed, metres_of: 250, lat: zone.lat, lon: zone.lon
    end
  end

  # --- The 2018 attack --------------------------------------------------------

  test "the cut points of rides leaving home in every direction do not fit a circle around home" do
    offset = trim(bearing_deg: 30.0, offset_m: 200.0) # ρ = 700 m
    cut_points = (0...8).map { |i| ride(length_m: 3_000, bearing: i * 45.0, every_m: 2.0).trim(offset).points.first }

    centre_lat, centre_lon, radius = fit_circle(cut_points)
    from_home = Track::Geo.distance_m(0.0, 0.0, centre_lat, centre_lon)

    assert_in_delta 200, from_home, 10, "the fitted centre should be |o| from home, not on it"
    assert_in_delta 700, radius, 10
    assert_in_delta 30.0, bearing_from_home(centre_lat, centre_lon), 3
  end

  test "a new radius keeps the centre, so two radii give two circles around one point rather than two fits" do
    small = trim(radius_m: 400, bearing_deg: 200.0, offset_m: 180.0)
    large = trim(radius_m: 900, bearing_deg: 200.0, offset_m: 180.0)

    a = small.circle_around(0.0, 0.0)
    b = large.circle_around(0.0, 0.0)
    assert_equal [ a.lat, a.lon ], [ b.lat, b.lon ]
    assert_in_delta 180.0, Track::Geo.distance_m(0.0, 0.0, a.lat, a.lon), 1e-6
    assert_equal [ 580.0, 1080.0 ], [ a.radius_m, b.radius_m ]

    # And a zone's circle is offset by the same distance, whatever its radius.
    zone = small.circle_around(0.0, 0.01, 150)
    assert_in_delta 180.0, Track::Geo.distance_m(0.0, 0.01, zone.lat, zone.lon), 1e-6
    assert_equal 330.0, zone.radius_m
  end

  # --- Nothing about the removed part survives --------------------------------

  test "every segment's times start at 0, and nothing absolute survives" do
    zone = Track::Zone.new(lat: 0.0, lon: Track::Geo.destination(0.0, 0.0, 90.0, 3_000).last, radius_m: 300)
    trimmed = ride(length_m: 6_000).trim(trim, zones: [ zone ])

    assert_equal [ 0, 0 ], trimmed.segments.map { |segment| segment.first.time }
    assert trimmed.points.all? { |point| point.time < 1_790_000_000 }
    assert_equal [ 0, 0 ], JSON.parse(trimmed.to_geojson).dig("properties", "times").map(&:first)
  end

  test "the numbers are the trimmed track's" do
    track = ride(length_m: 5_000)
    trimmed = track.trim(trim)

    assert_operator trimmed.distance_m, :<, track.distance_m - 1_000
    assert_operator trimmed.moving_time_s, :<, track.moving_time_s
  end

  private
    def assert_same_geojson(expected, actual, message)
      assert_equal expected["type"], actual["type"], message
      assert_equal expected.dig("geometry", "type"), actual.dig("geometry", "type"), message
      assert_equal expected["properties"].keys, actual["properties"].keys, message
      if expected.dig("properties", "times")
        assert_equal expected.dig("properties", "times"), actual.dig("properties", "times"), message
      end

      expected_segments = expected.dig("geometry", "coordinates")
      actual_segments = actual.dig("geometry", "coordinates")
      assert_equal expected_segments.map(&:size), actual_segments.map(&:size), message

      expected_segments.flatten(1).zip(actual_segments.flatten(1)).each do |want, got|
        assert_equal want.size, got.size, message
        want.zip(got).each { |a, b| assert_in_delta a, b, 1e-9, message }
      end
    end

    # Least-squares circle (Kåsa) through points, in metres on a local plane:
    # solve x² + y² + Dx + Ey + F = 0, centre (-D/2, -E/2).
    def fit_circle(points)
      xy = points.map { |p| [ Track::Geo.radians(p.lon) * Track::Geo::EARTH_RADIUS_M, Track::Geo.radians(p.lat) * Track::Geo::EARTH_RADIUS_M ] }
      sums = Hash.new(0.0)
      xy.each do |x, y|
        z = x * x + y * y
        sums[:xx] += x * x; sums[:xy] += x * y; sums[:yy] += y * y
        sums[:x] += x; sums[:y] += y; sums[:n] += 1
        sums[:xz] += x * z; sums[:yz] += y * z; sums[:z] += z
      end

      d, e, f = solve3(
        [ [ sums[:xx], sums[:xy], sums[:x] ], [ sums[:xy], sums[:yy], sums[:y] ], [ sums[:x], sums[:y], sums[:n] ] ],
        [ -sums[:xz], -sums[:yz], -sums[:z] ]
      )
      cx, cy = -d / 2, -e / 2
      radius = Math.sqrt(cx * cx + cy * cy - f)

      [ Track::Geo.degrees(cy / Track::Geo::EARTH_RADIUS_M), Track::Geo.degrees(cx / Track::Geo::EARTH_RADIUS_M), radius ]
    end

    def solve3(a, b)
      det = ->(m) {
        m[0][0] * (m[1][1] * m[2][2] - m[1][2] * m[2][1]) -
          m[0][1] * (m[1][0] * m[2][2] - m[1][2] * m[2][0]) +
          m[0][2] * (m[1][0] * m[2][1] - m[1][1] * m[2][0])
      }
      whole = det.(a)
      (0..2).map { |col| det.(a.each_with_index.map { |row, i| row.dup.tap { |r| r[col] = b[i] } }) / whole }
    end

    def bearing_from_home(lat, lon)
      Track::Geo.degrees(Math.atan2(lon, lat)) % 360
    end
end
