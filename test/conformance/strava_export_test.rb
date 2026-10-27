require "test_helper"

# A real Strava export, run end to end. It is never in the repository: point
# KITH_STRAVA_EXPORT at one to run this, and without it the test skips.
#
#   KITH_STRAVA_EXPORT=~/Development/kith/strava-export/export_7448.zip \
#     bin/rails test test/conformance/strava_export_test.rb
#
# The original files are the answer key three times over: each stored track
# is its file's points, rounded to six places; it holds as many points as a
# count of the file's own XML finds; and Track#trim over every ride leaves
# nothing within the member's radius of either recorded end, with no
# tolerance. That proves the trim on real rides before anything shares one.
#
# The first check reads each file with Track.read, the reader under test, so
# it proves the round trip through storage and not the reading. The count is
# the independent key: Nokogiri, without Track, over every GPX and TCX. A FIT
# has no XML to count, and its reader is the only one written by hand, so it
# is checked against Strava's own distance instead: the median, over every FIT
# ride of 100 m or more, of the stored track's distance over Strava's, which
# was 0.999 when the reader was written (f0fa317). A median, because a GPS
# glitch throws off one ride and a misread position (scale, byte order, the
# wrong field) throws off all of them. It does not catch dropped records: at
# one a second, keeping every other one barely moves a ride's distance. Those
# are left to the FIT tests in test/models/track/read_test.rb.
#
# Every failure names activity ids, never a value: an assert_equal on two
# tracks would print a member's coordinates into the test output. The FIT
# check reports its median and how many rides it counted, and no one ride's
# distance.
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

    not_as_recorded, miscounted, not_from_zero, trimmed_too_little, fit_ratios = [], [], [], [], []

    Zip::File.open(@path) do |zip|
      rows.each do |id, filename|
        stored = workouts.fetch(id).read_full_track
        recorded = filename.blank? ? Track.new([]) : read(zip, filename)

        not_as_recorded << id unless as_recorded?(stored, recorded)
        count = counted(zip, filename)
        miscounted << id unless count.nil? || stored.points.size == (count < 2 ? 0 : count)
        not_from_zero << id unless stored.segments.all? { |segment| segment.first.time.nil? || segment.first.time.zero? }
        trimmed_too_little << id unless trimmed_clear_of_its_ends?(stored)

        strava_m = workouts.fetch(id).data["distance_m"]
        fit_ratios << stored.distance_m / strava_m if fit?(filename) && strava_m.to_f >= 100
      end
    end

    assert_empty not_as_recorded, "these stored tracks are not their file's points, rounded to 6 places"
    assert_empty miscounted, "these stored tracks do not hold as many points as their file's XML"
    assert_empty not_from_zero, "these stored tracks have a segment whose times do not start at 0"
    assert_empty trimmed_too_little, "the trim left a point within #{@member.trim_radius_m} m of an end of these"

    median = fit_ratios.sort.then { |r| r.empty? ? nil : (r[(r.size - 1) / 2] + r[r.size / 2]) / 2 }
    assert median&.between?(0.99, 1.01),
      "the median FIT distance over Strava's is #{median&.round(4).inspect}, over #{fit_ratios.size} rides"

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

    # How many positions a GPX or TCX holds, counted without Track: a GPX's
    # trkpts inside a trkseg, and a TCX's Trackpoints that have a Position. A
    # lone point in a GPX segment is kept, so every one counts; a whole file
    # of fewer than two is no line at all. nil for a FIT, or no file.
    def counted(zip, filename)
      format = filename.to_s[StravaExport::FILENAME, 1] or return
      return if fit?(filename)

      data = zip.find_entry(filename).get_input_stream(&:read)
      data = Zlib.gunzip(data) if format.end_with?(".gz")
      document = Nokogiri::XML(data.b.lstrip)

      if format.start_with?("gpx")
        document.xpath("//*[local-name()='trkseg']/*[local-name()='trkpt']").size
      else
        document.xpath("//*[local-name()='Trackpoint'][*[local-name()='Position']]").size
      end
    end

    def fit?(filename) = filename.to_s[StravaExport::FILENAME, 1].to_s.start_with?("fit")

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
