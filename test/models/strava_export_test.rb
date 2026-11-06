require "test_helper"
require_relative "../test_helpers/fit_writer"
require_relative "../test_helpers/strava_export_builder"

# Every export here is built on the fly by StravaExportBuilder.
class StravaExportTest < ActiveSupport::TestCase
  include ActiveJob::TestHelper
  include StravaExportBuilder

  # Records which zip entries were opened, so a test can prove the rest never
  # were. Inert outside `opened_entries`.
  module OpenedEntries
    def get_input_stream(...)
      Thread.current[:opened_entries]&.push(name)
      super
    end
  end
  Zip::Entry.prepend(OpenedEntries)

  setup do
    @member = members(:alice)
    @dir = Dir.mktmpdir
  end

  teardown { FileUtils.remove_entry(@dir) }

  # A file's track as it is stored: every point, with times relative to each
  # segment's start.
  def stored(data, format) = Track.from_geojson(Track.read(StringIO.new(data), format:).to_geojson)

  def import(path = export, **options) = StravaExport.new(member: @member, path:, **options).import

  def source = @member.sources.strava_export.first
  def workout(id) = Workout.find_by!(source:, external_id: id.to_s)

  def opened_entries
    Thread.current[:opened_entries] = []
    yield
    Thread.current[:opened_entries]
  ensure
    Thread.current[:opened_entries] = nil
  end

  def assert_refused(path, message = nil, **options)
    assert_no_difference [ "Entry.count", "Source.count", "ActiveStorage::Blob.count" ] do
      error = assert_raises(StravaExport::Refused) { import(path, **options) }
      assert_match message, error.message if message
    end
  end

  # --- A first import ----------------------------------------------------------

  test "a first import creates a draft workout per activity, under the member's Strava source" do
    result = import

    assert_equal [ 2, 0, 0, 0, [] ], result.to_h.values_at(:created, :updated, :unchanged, :removed, :failed)
    assert_equal [ "101", "102" ], source.entries.order(:external_id).pluck(:external_id)
    assert source.entries.all?(&:draft?)
    assert source.entries.all? { |entry| entry.is_a?(Workout) && entry.actor == @member.actor }
    assert_in_delta Time.current, source.last_imported_at, 5.seconds
  end

  test "data holds exactly a workout's keys, with Strava's own figures in SI units" do
    import

    assert_equal({ "name" => "Ride 101", "activity_type" => "ride", "source_activity_type" => "Ride",
      "distance_m" => 3331.3, "moving_time_s" => 1235, "elevation_gain_m" => 19.2 }, workout(101).data)
  end

  test "what Kith must never keep never reaches data" do
    import

    stored = Entry.pluck(:data).to_json
    [ "private note", "80.0", "description", "the bike", "171", "400", "1262" ].each do |value|
      assert_not_includes stored, value
    end
  end

  test "occurred_at is the Activity Date, read as UTC" do
    import

    assert_equal Time.utc(2026, 9, 19, 4, 23, 34), workout(101).occurred_at
  end

  test "every workout has Strava's numbers, tracked or not" do
    path = export(rows: [ row(101, distance_m: "12.5", "Moving Time" => "61.0", "Elevation Gain" => ""),
                          row(103, filename: "", "Activity Type" => "Weight Training") ])
    import(path)

    assert_equal [ 12.5, 61, nil ], workout(101).data.values_at("distance_m", "moving_time_s", "elevation_gain_m")
    assert_equal [ 3331.3, 1235, 19.2 ], workout(103).data.values_at("distance_m", "moving_time_s", "elevation_gain_m")
    assert_equal "other", workout(103).activity_type
    refute workout(103).full_track.attached?, "a blank Filename is an entry with no track"
  end

  test "Strava's activity types map onto Kith's" do
    assert_equal "run", StravaExport.activity_type("Trail Run")
    assert_equal "ride", StravaExport.activity_type("E-Bike Ride")
    assert_equal "ride", StravaExport.activity_type("Virtual Ride")
    assert_equal "ski", StravaExport.activity_type("Nordic Ski")
    assert_equal "snowboard", StravaExport.activity_type("Snowboard")
    assert_equal "other", StravaExport.activity_type("Kitesurf")
    assert_equal "other", StravaExport.activity_type(nil)
    assert StravaExport::ACTIVITY_TYPES.values.all? { |type| Workout::ACTIVITY_TYPES.include?(type) }
  end

  test "uri is NULL: a workout never links to Strava" do
    import

    assert Entry.all.all? { |entry| entry.uri.nil? }
  end

  # --- The track ------------------------------------------------------------------

  test "the stored full track is the whole ride, point for point, and nothing is trimmed" do
    import

    assert_equal stored(gpx, "gpx"), workout(101).read_full_track
    assert_equal stored(tcx, "tcx"), workout(102).read_full_track
    assert_equal [ 3, 2 ], workout(101).read_full_track.segments.map(&:size), "every point the file has"
    assert_equal "application/geo+json", workout(101).full_track.content_type
  end

  test "FIT and gzipped FIT files are read" do
    fit = FitWriter.build do |f|
      f.define(local: 0, global: 20, fields: [ [ 253, 4 ], [ 0, 4 ], [ 1, 4 ] ])
      f.record(local: 0, values: [ 1_000_000_000, FitWriter.semicircles(-10.0), FitWriter.semicircles(-140.0) ])
      f.record(local: 0, values: [ 1_000_000_010, FitWriter.semicircles(-10.0), FitWriter.semicircles(-139.999) ])
    end
    path = export(rows: [ row(201, filename: "activities/201.fit"), row(202, filename: "activities/202.fit.gz") ],
      files: { "activities/201.fit" => fit, "activities/202.fit.gz" => ActiveSupport::Gzip.compress(fit) })

    assert_empty import(path).failed
    assert_equal [ -140.0, -139.999 ], workout(201).read_full_track.points.map(&:lon)
    assert_equal workout(201).read_full_track, workout(202).read_full_track
  end

  test "an indoor activity, whose file has no positions, is an entry with no track" do
    path = export(rows: [ row(301, filename: "activities/301.tcx") ],
      files: { "activities/301.tcx" => TRACKS.join("indoor.tcx").read })

    assert_equal 1, import(path).created
    refute workout(301).full_track.attached?
  end

  # --- Running it again --------------------------------------------------------------

  test "importing the same export again writes nothing" do
    path = export
    import(path)
    before = Entry.order(:id).pluck(:id, :updated_at)

    result = assert_no_difference -> { ActiveStorage::Blob.count } do
      import(path)
    end

    assert_equal [ 0, 0, 2, 0 ], result.to_h.values_at(:created, :updated, :unchanged, :removed)
    assert_equal before, Entry.order(:id).pluck(:id, :updated_at)
  end

  test "a renamed activity updates its draft, and nothing else" do
    import
    untouched = workout(102).updated_at

    travel 1.minute do
      result = import(export(rows: [ row(101, "Activity Name" => "Renamed"), row(102, filename: "activities/102.tcx.gz") ]))
      assert_equal [ 0, 1, 1 ], result.to_h.values_at(:created, :updated, :unchanged)
    end

    assert_equal "Renamed", workout(101).data["name"]
    assert_equal untouched, workout(102).updated_at
  end

  test "a draft whose file changed gets the new track" do
    import
    moved = gpx.sub('lon="-139.9890000"', 'lon="-139.9880000"')
    assert_not_equal moved, gpx

    result = import(export(files: { "activities/101.gpx" => moved, "activities/102.tcx.gz" => ActiveSupport::Gzip.compress(tcx) }))

    assert_equal 1, result.updated
    assert_equal stored(moved, "gpx"), workout(101).read_full_track
  end

  test "a published workout is never touched by a re-run that changed it" do
    import
    workout(101).update!(published_at: Time.current)
    before = workout(101).attributes

    result = import(export(rows: [ row(101, "Activity Name" => "Renamed", "Activity Type" => "Run"),
                                   row(102, filename: "activities/102.tcx.gz") ]))

    assert_equal 0, result.updated
    assert_equal before, workout(101).attributes
  end

  test "a draft missing from a newer export is destroyed and its track purged; a published one stays" do
    import(export(rows: [ row(101), row(102, filename: "activities/102.tcx.gz"), row(103, filename: "") ]))
    workout(103).update!(published_at: Time.current)
    gone = workout(101).full_track.blob

    result = perform_enqueued_jobs do
      import(export(rows: [ row(102, filename: "activities/102.tcx.gz") ]))
    end

    assert_equal 1, result.removed
    refute Workout.exists?(external_id: "101")
    refute ActiveStorage::Blob.exists?(gone.id)
    assert Workout.exists?(external_id: "103"), "a published workout is the member's own by now"
  end

  # --- Failures ----------------------------------------------------------------------

  test "a corrupt activity file is listed by id and class, the rest import, and it gets no partial entry" do
    path = export(rows: [ row(101), row(104) ], files: { "activities/101.gpx" => gpx, "activities/104.gpx" => "<gpx><trk" })

    result = assert_difference -> { ActiveStorage::Blob.count }, 1 do
      import(path)
    end

    assert_equal [ [ "104", "Track::Malformed" ] ], result.failed
    assert_equal 1, result.created
    refute Workout.exists?(external_id: "104")
  end

  test "an activity whose file failed is still in the CSV, so its existing draft is not removed" do
    import
    result = import(export(files: { "activities/101.gpx" => "<gpx><trk", "activities/102.tcx.gz" => ActiveSupport::Gzip.compress(tcx) }))

    assert_equal [ [ "101", "Track::Malformed" ] ], result.failed
    assert_equal 0, result.removed
    assert_equal stored(gpx, "gpx"), workout(101).read_full_track
  end

  test "a Filename outside activities/ is refused and never opened" do
    path = export(rows: [ row(101), row(105, filename: "messaging.json"), row(106, filename: "activities/../logins.csv"),
                          row(107, filename: "activities/107.kml") ],
      files: { "activities/101.gpx" => gpx, "messaging.json" => "{}", "logins.csv" => "secret" })

    result = nil
    opened = opened_entries { result = import(path) }

    assert_equal [ "activities.csv", "activities/101.gpx" ], opened
    assert_equal [ [ "105", "StravaExport::UnsafeFilename" ], [ "106", "StravaExport::UnsafeFilename" ],
                   [ "107", "StravaExport::UnsafeFilename" ] ], result.failed
  end

  test "a Filename that names nothing in the zip fails that activity" do
    result = import(export(rows: [ row(101), row(108) ]))

    assert_equal [ [ "108", "StravaExport::MissingFile" ] ], result.failed
  end

  test "privacy_zones.csv and everything else in the export is never opened" do
    files = { "activities/101.gpx" => gpx, "activities/102.tcx.gz" => ActiveSupport::Gzip.compress(tcx),
              "privacy_zones.csv" => "Address,Radius,Latitude & Longitude\n", "logins.csv" => "", "profile.csv" => "" }

    opened = opened_entries { import(export(files:)) }

    assert_equal [ "activities.csv", "activities/101.gpx", "activities/102.tcx.gz" ], opened
  end

  test "an entry that decompresses past the limit fails, however small it is in the zip" do
    bomb = ActiveSupport::Gzip.compress(" " * 200_000)
    path = export(rows: [ row(101), row(109, filename: "activities/109.gpx.gz") ],
      files: { "activities/101.gpx" => gpx, "activities/109.gpx.gz" => bomb })

    result = import(path, limit: 100_000)

    assert_equal [ [ "109", "Track::TooLarge" ] ], result.failed
    assert_equal 1, result.created
  end

  test "failures carry ids and class names, never a message" do
    result = import(export(rows: [ row(104) ], files: { "activities/104.gpx" => "<gpx><trk" }))

    assert result.failed.flatten.all? { |value| value.match?(/\A(\d+|[A-Z][\w:]*)\z/) }
  end

  # --- Refusals: nothing is written --------------------------------------------------

  test "a missing required column refuses the import, with nothing written" do
    assert_refused export(csv: csv([ row(101).values_at(0..10) ], header: HEADER.first(11))), "Filename"
  end

  test "Distance other than exactly twice refuses the import" do
    header = HEADER.each_with_index.map { |name, index| index == 6 ? "Distance (km)" : name }
    assert_refused export(csv: csv([ row(101) ], header:)), "Distance 1 times, not 2"
  end

  test "any other column twice refuses the import" do
    header = HEADER.map { |name| name == "Calories" ? "Moving Time" : name }
    assert_refused export(csv: csv([ row(101) ], header:)), "Moving Time 2 times, not 1"
  end

  test "a CSV with no rows refuses the import" do
    assert_refused export(rows: []), "no activities"
  end

  test "an empty CSV refuses the import" do
    assert_refused export(csv: ""), "empty"
  end

  test "a blank, non-numeric or repeated Activity ID refuses the import" do
    assert_refused export(rows: [ row(101), row("") ]), "blank or not a number"
    assert_refused export(rows: [ row(101), row("10x") ]), "blank or not a number"
    assert_refused export(rows: [ row(101), row(101) ]), "appears twice"
  end

  test "a CSV that cannot be parsed refuses the import" do
    assert_refused export(csv: csv([ row(101) ]) + %(1,"unterminated\n)), "cannot be read"
  end

  test "a corrupt or empty CSV never deletes anybody's drafts" do
    import

    assert_no_difference -> { Entry.count } do
      assert_raises(StravaExport::Refused) { import(export(rows: [])) }
      assert_raises(StravaExport::Refused) { import(export(csv: "garbage")) }
    end
  end

  test "an export with no activities.csv, or a file that is not a zip, is refused" do
    path = File.join(@dir, "no-csv.zip")
    Zip::File.open(path, create: true) { |zip| zip.get_output_stream("activities/101.gpx") { _1.write(gpx) } }
    assert_refused path, "no activities.csv"

    not_zip = File.join(@dir, "not.zip").tap { File.write(_1, "not a zip") }
    assert_refused not_zip, "not a zip"
  end

  # A zip's central directory is read whole when it is opened, and a crafted
  # one can list millions of entries. The count is in the zip's last few
  # bytes, so it is checked there, before the directory is parsed at all.
  test "a zip of more entries than the cap is refused before any entry is read" do
    path = export # activities.csv and two activity files

    opened = opened_entries { assert_refused path, "more than 2 entries", max_entries: 2 }

    assert_empty opened
    assert_equal 2, import(path, max_entries: 3).created
  end

  test "an oversized activities.csv refuses the import" do
    path = export

    assert_no_difference [ "Entry.count", "Source.count" ] do
      error = assert_raises(StravaExport::Refused) { import(path, limit: 10) }
      assert_match "cannot be read (Track::TooLarge)", error.message
    end
  end
end
