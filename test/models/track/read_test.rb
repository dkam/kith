require "test_helper"
require_relative "../../test_helpers/fit_writer"

# Every fixture is invented, in the open Pacific near 10° S 140° W.
class Track::ReadTest < ActiveSupport::TestCase
  TRACKS = Rails.root.join("test/fixtures/files/tracks")
  START = Time.utc(2026, 9, 19, 4, 23, 34)

  def read(data, format:, **options)
    Track.read(StringIO.new(data.b), format:, **options)
  end

  def gzip(data) = ActiveSupport::Gzip.compress(data)

  # --- GPX ---------------------------------------------------------------------

  test "a GPX keeps its segments, elevation and times, and ignores waypoints" do
    track = read(TRACKS.join("ride.gpx").read, format: "gpx")

    assert_equal [ 3, 2 ], track.segments.map(&:size)
    assert_equal [ -140.0, -10.0, 12.0, START.to_i ], track.points.first.to_h.values_at(:lon, :lat, :ele, :time)
    assert_equal [ -139.989, -10.0, 15.5, START.to_i + 406 ], track.points.last.to_h.values_at(:lon, :lat, :ele, :time)
  end

  test "a gzipped GPX reads the same" do
    plain = read(TRACKS.join("ride.gpx").read, format: "gpx")

    assert_equal plain, read(gzip(TRACKS.join("ride.gpx").read), format: "gpx.gz")
  end

  test "XML that is not well-formed is malformed" do
    assert_raises(Track::Malformed) { read("<gpx><trk><trkseg><trkpt lat=", format: "gpx") }
  end

  test "a position out of range is malformed" do
    gpx = TRACKS.join("ride.gpx").read.sub('lat="-10.0000000" lon="-140.0000000"', 'lat="-100" lon="-140"')

    assert_raises(Track::Malformed) { read(gpx, format: "gpx") }
  end

  # --- TCX ---------------------------------------------------------------------

  test "a TCX with whitespace before its declaration still reads" do
    assert TRACKS.join("ride.tcx").read.start_with?(" ")

    track = read(TRACKS.join("ride.tcx").read, format: "tcx")

    # Laps are contiguous, so they are one segment; the trackpoint with no
    # position is skipped.
    assert_equal [ 3 ], track.segments.map(&:size)
    assert_equal [ -140.0, -139.999, -139.998 ], track.points.map(&:lon)
    assert_equal [ 12.0, 12.5, 13.0 ], track.points.map(&:ele)
    assert_equal [ 0, 20, 40 ], track.points.map { |point| point.time - START.to_i }
  end

  test "an indoor TCX, with no positions at all, is an empty track" do
    assert read(TRACKS.join("indoor.tcx").read, format: "tcx").empty?
  end

  test "a gzipped TCX reads the same" do
    assert_equal read(TRACKS.join("ride.tcx").read, format: "tcx"), read(gzip(TRACKS.join("ride.tcx").read), format: "tcx.gz")
  end

  # --- FIT ---------------------------------------------------------------------

  # The last full timestamp before the compressed record ends in 0b11110, so a
  # compressed offset of 2 rolls over: 30 → 34, not 30 → 2.
  def base_timestamp
    t = FitWriter.timestamp(START)
    t + (30 - (t + 20)) % 32
  end

  def lat(degrees) = FitWriter.semicircles(degrees)
  def altitude(metres) = ((metres + 500) * 5).round

  def ride_fit(header_size: 14)
    t = base_timestamp

    FitWriter.build(header_size:) do |fit|
      # file_id, which the decoder must step over.
      fit.define(local: 3, global: 0, fields: [ [ 0, 1 ], [ 1, 2 ], [ 4, 4 ] ])
      fit.record(local: 3, values: [ 4, 1, t ])

      # Records, little-endian, with an array field the decoder knows nothing
      # about between the ones it wants.
      fit.define(local: 0, global: 20, fields: [ [ 253, 4 ], [ 0, 4 ], [ 1, 4 ], [ 99, 3 ], [ 2, 2 ], [ 78, 4 ] ])
      fit.record(local: 0, values: [ t, lat(-10.0), lat(-140.0), 0, altitude(10.0), 0xFFFFFFFF ])
      # enhanced_altitude beside altitude: enhanced wins.
      fit.record(local: 0, values: [ t + 10, lat(-10.0), lat(-139.999), 0, altitude(50.0), altitude(12.4) ])
      # No valid position: skipped.
      fit.record(local: 0, values: [ t + 15, 0x7FFFFFFF, 0x7FFFFFFF, 0, altitude(13.0), 0xFFFFFFFF ])

      # Big-endian, with a developer field the decoder has to skip.
      fit.define(local: 1, global: 20, fields: [ [ 253, 4 ], [ 0, 4 ], [ 1, 4 ], [ 78, 4 ] ],
        big_endian: true, developer_fields: [ [ 0, 2, 0 ] ])
      fit.record(local: 1, values: [ t + 20, lat(-10.0), lat(-139.998), altitude(13.6) ], developer_bytes: [ 0xAB, 0xCD ])

      # A compressed-timestamp record, with no timestamp field of its own.
      fit.define(local: 2, global: 20, fields: [ [ 0, 4 ], [ 1, 4 ], [ 78, 4 ] ])
      fit.compressed(local: 2, offset: 2, values: [ lat(-10.0), lat(-139.997), altitude(14.0) ])
    end
  end

  test "a FIT file's records become a track, whatever their byte order" do
    track = read(ride_fit, format: "fit")
    t = base_timestamp + FitWriter::EPOCH

    assert_equal [ 4 ], track.segments.map(&:size)
    assert_equal [ -140.0, -139.999, -139.998, -139.997 ], track.points.map(&:lon)
    assert_equal [ -10.0 ] * 4, track.points.map(&:lat)
    assert_equal [ 10.0, 12.4, 13.6, 14.0 ], track.points.map(&:ele)
    assert_equal [ t, t + 10, t + 20, t + 24 ], track.points.map(&:time)
  end

  test "a FIT file with the 12-byte header reads the same" do
    assert_equal read(ride_fit, format: "fit"), read(ride_fit(header_size: 12), format: "fit")
  end

  test "a gzipped FIT file reads the same" do
    assert_equal read(ride_fit, format: "fit"), read(gzip(ride_fit), format: "fit.gz")
  end

  test "a FIT file with no records that have a position is an empty track" do
    fit = FitWriter.build do |f|
      f.define(local: 0, global: 20, fields: [ [ 253, 4 ], [ 0, 4 ], [ 1, 4 ] ])
      f.record(local: 0, values: [ base_timestamp, 0x7FFFFFFF, lat(-140.0) ])
    end

    assert read(fit, format: "fit").empty?
  end

  test "anything after the header's data size is ignored, and the CRC is never checked" do
    assert_equal read(ride_fit, format: "fit"), read(ride_fit + "trailing nonsense", format: "fit")
  end

  test "a FIT file that is not one is malformed" do
    assert_raises(Track::Malformed) { read("not a fit file at all", format: "fit") }
    assert_raises(Track::Malformed) { read(ride_fit.sub(".FIT", ".TIF"), format: "fit") }
  end

  test "a truncated FIT file is malformed" do
    fit = ride_fit
    assert_raises(Track::Malformed) { read(fit[0, fit.bytesize - 20], format: "fit") }
  end

  test "a data record with no definition is malformed" do
    fit = FitWriter.build { |f| f.instance_variable_get(:@records) << [ 5, 1, 2, 3 ].pack("C*") }

    assert_raises(Track::Malformed) { read(fit, format: "fit") }
  end

  # --- Limits ------------------------------------------------------------------

  test "more than the limit is refused, counted as it is read" do
    assert_raises(Track::TooLarge) { read(TRACKS.join("ride.gpx").read, format: "gpx", limit: 100) }
  end

  test "a small gzip that inflates past the limit is refused" do
    bomb = gzip(" " * 100_000)
    assert_operator bomb.bytesize, :<, 1_000

    assert_raises(Track::TooLarge) { read(bomb, format: "gpx.gz", limit: 10_000) }
  end

  test "a gzip that is not one is malformed" do
    assert_raises(Track::Malformed) { read("not gzip", format: "gpx.gz") }
  end

  test "an unknown format is refused" do
    assert_raises(ArgumentError) { read("", format: "kml") }
    assert_raises(ArgumentError) { read("", format: "gpx.zip") }
  end
end
