require "test_helper"

# A real Strava export, run end to end. It is never in the repository: point
# KITH_STRAVA_EXPORT at one to run this, and without it the test skips.
#
#   KITH_STRAVA_EXPORT=~/Development/kith/strava-export/export_7448.zip \
#     bin/rails test test/conformance/strava_export_test.rb
#
# The original files are the answer key twice over: each stored track is its
# file's points, rounded to six places, and Track#trim over every ride leaves
# nothing within the member's radius of either recorded end, with no
# tolerance. That proves the trim on real rides before anything shares one.
#
# Every failure names activity ids, never a value: an assert_equal on two
# tracks would print a member's coordinates into the test output.
class StravaExportConformanceTest < ActiveSupport::TestCase
  setup do
    @path = ENV["KITH_STRAVA_EXPORT"].presence&.then { File.expand_path(_1) }
    skip "set KITH_STRAVA_EXPORT to a Strava export zip to run this" unless @path && File.file?(@path)

    @member = members(:alice)
  end

  test "a real export imports whole, stores every ride as recorded, and trims every one" do
    result = StravaExport.new(member: @member, path: @path).import
    rows = csv_rows

    assert_empty result.failed.map(&:first), "these activities failed to import"
    assert_equal rows.size, result.created
    assert_equal 0, result.removed

    workouts = @member.sources.strava_export.first.entries.index_by(&:external_id)
    assert_equal rows.keys.sort, workouts.keys.sort

    not_as_recorded, not_from_zero, trimmed_too_little = [], [], []

    Zip::File.open(@path) do |zip|
      rows.each do |id, filename|
        stored = workouts.fetch(id).read_full_track
        recorded = filename.blank? ? Track.new([]) : read(zip, filename)

        not_as_recorded << id unless as_recorded?(stored, recorded)
        not_from_zero << id unless stored.segments.all? { |segment| segment.first.time.nil? || segment.first.time.zero? }
        trimmed_too_little << id unless trimmed_clear_of_its_ends?(stored)
      end
    end

    assert_empty not_as_recorded, "these stored tracks are not their file's points, rounded to 6 places"
    assert_empty not_from_zero, "these stored tracks have a segment whose times do not start at 0"
    assert_empty trimmed_too_little, "the trim left a point within #{@member.trim_radius_m} m of an end of these"

    again = StravaExport.new(member: @member, path: @path).import
    assert_equal [ 0, 0, 0, [] ], again.to_h.values_at(:created, :updated, :removed, :failed).then { |c, u, r, f| [ c, u, r, f.map(&:first) ] }
  end

  private
    # Activity id => Filename, read the way the importer reads them.
    def csv_rows
      Zip::File.open(@path) do |zip|
        header, *rows = CSV.parse(zip.find_entry("activities.csv").get_input_stream(&:read).force_encoding(Encoding::UTF_8))
        id, filename = header.index("Activity ID"), header.index("Filename")
        rows.to_h { |row| [ row[id], row[filename] ] }
      end
    end

    def read(zip, filename)
      format = filename[StravaExport::FILENAME, 1]
      zip.find_entry(filename).get_input_stream { |io| Track.read(io, format:) }
    end

    # Point for point, positions and elevation exactly; times as the stored
    # form keeps them, relative to each segment's first point.
    def as_recorded?(stored, recorded)
      return stored.empty? if recorded.empty?

      stored.segments.size == recorded.segments.size &&
        stored.segments.zip(recorded.segments).all? { |kept, original|
          kept.size == original.size &&
            kept.zip(original).all? { |a, b|
              [ a.lon, a.lat, a.ele ] == [ b.lon, b.lat, b.ele ] &&
                a.time == (b.time && (b.time - original.first.time).round)
            }
        }
    end

    def trimmed_clear_of_its_ends?(stored)
      return true if stored.empty?

      trimmed = stored.trim(@member.trim)
      ends = [ stored.points.first, stored.points.last ]

      trimmed.points.none? { |point|
        ends.any? { |e| Track::Geo.distance_m(e.lat, e.lon, point.lat, point.lon) < @member.trim_radius_m }
      }
    end
end
