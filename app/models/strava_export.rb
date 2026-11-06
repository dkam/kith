require "csv"

# Imports a member's Strava account export — the zip Strava emails on request —
# as draft Workouts. Running it again with a newer export is how new rides
# arrive: exports are cumulative, and each activity is keyed on its Strava id,
# as external_id under the member's strava_export source.
#
#   StravaExport.new(member:, path: "export_7448.zip").import
#   # => #<data Result created=12, updated=1, unchanged=362, removed=0, failed=[]>
#
# An export is the whole account: logins, messages, device ids, followers and
# privacy zones with street addresses in them. So it is read by allowlist —
# activities.csv, and the activities/ files its Filename column names — and
# every other entry is never opened. Nothing is extracted to disk.
#
# Nothing printed by or raised from here may carry a name or a coordinate.
# Errors name the part that is wrong, and `failed` holds activity ids and
# exception class names, never messages.
class StravaExport
  # The whole import was refused, before anything was written.
  class Refused < StandardError; end
  # A Filename that is not one of activities/<id>.<format>. Never opened.
  class UnsafeFilename < StandardError; end
  # A Filename that names nothing in the zip.
  class MissingFile < StandardError; end

  Result = Data.define(:created, :updated, :unchanged, :removed, :failed)

  CSV_NAME = "activities.csv"
  FILENAME = %r{\Aactivities/\d+\.((?:gpx|tcx|fit)(?:\.gz)?)\z}

  # Every column read, by name. Strava's CSV repeats Distance (and Elapsed
  # Time, Commute and others): a first block in display units — Distance in
  # km — and a second in SI. The SI Distance is the last, so it must appear
  # exactly twice; anything else would make "the last" whichever block was
  # left. Every other column must appear exactly once. A missing or doubled
  # column refuses the whole import: Strava changes this file, and a silent
  # mis-map is worse than a loud stop.
  COLUMNS = {
    id: "Activity ID", date: "Activity Date", name: "Activity Name", type: "Activity Type",
    filename: "Filename", distance: "Distance", moving_time: "Moving Time", elevation_gain: "Elevation Gain"
  }.freeze
  TWICE = %i[ distance ].freeze

  # e.g. "Sep 19, 2026, 4:23:34 AM", in UTC.
  DATE_FORMAT = "%b %d, %Y, %l:%M:%S %p"

  # Strava's names onto Kith's own (Workout::ACTIVITY_TYPES). Anything not
  # here is `other`.
  ACTIVITY_TYPES = {
    "run" => [ "Run", "Trail Run", "Virtual Run" ],
    "ride" => [ "Ride", "Virtual Ride", "E-Bike Ride", "Mountain Bike Ride", "E-Mountain Bike Ride",
      "Gravel Ride", "Velomobile", "Handcycle" ],
    "walk" => [ "Walk" ],
    "hike" => [ "Hike" ],
    "swim" => [ "Swim" ],
    "ski" => [ "Alpine Ski", "Backcountry Ski", "Nordic Ski", "Roller Ski" ],
    "snowboard" => [ "Snowboard" ]
  }.flat_map { |kith, stravas| stravas.map { |strava| [ strava, kith ] } }.to_h.freeze

  # Strava's own exports hold a file per activity and a few dozen besides.
  MAX_ENTRIES = 100_000

  attr_reader :member, :path, :limit, :max_entries

  # `limit` is the most any one entry may decompress to, counted as it is read
  # and including an inner .gz: an entry's declared size is whatever whoever
  # made the zip wanted it to say.
  def initialize(member:, path:, limit: Track::LIMIT, max_entries: MAX_ENTRIES)
    @member = member
    @path = path
    @limit = limit
    @max_entries = max_entries
  end

  def self.activity_type(strava_type) = ACTIVITY_TYPES.fetch(strava_type.to_s, "other")

  def import
    # Opening a zip reads its whole central directory, which can list millions
    # of entries. The count is in the end record, so it is checked first.
    entries = Zip::File.count_entries(path)
    raise Refused, "the export has more than #{max_entries} entries" if entries > max_entries

    Zip::File.open(path) do |zip|
      rows = activities(zip)
      source = member.sources.find_or_create_by!(kind: :strava_export)
      counts = Hash.new(0)
      failed = []

      rows.each do |row|
        counts[import_row(zip, source, row)] += 1
      rescue StandardError => e
        failed << [ row[:id], e.class.name ]
      end

      # Only after a clean parse of the whole CSV, which is the only way to get
      # here. A row whose file failed is still in the CSV, so it is not missing.
      removed = source.entries.drafts.where.not(external_id: rows.map { |row| row[:id] }).destroy_all.size
      source.update!(last_imported_at: Time.current)

      Result.new(created: counts[:created], updated: counts[:updated], unchanged: counts[:unchanged],
        removed:, failed:)
    end
  rescue Zip::Error
    raise Refused, "not a zip file"
  end

  private
    # The CSV, parsed and checked, as one hash of the columns Kith reads per
    # row. Refuses the import on anything wrong with the file as a whole.
    def activities(zip)
      entry = zip.find_entry(CSV_NAME) or raise Refused, "no #{CSV_NAME} in the export"
      data = entry.get_input_stream { |io| Track.read_at_most(io, limit) }
      header, *rows = CSV.parse(data.force_encoding(Encoding::UTF_8).delete_prefix("﻿"))
      raise Refused, "#{CSV_NAME} is empty" if header.nil?

      columns = COLUMNS.to_h { |key, name| [ key, column(header, key, name) ] }
      raise Refused, "#{CSV_NAME} has no activities" if rows.empty?

      rows = rows.map { |row| columns.transform_values { |index| row[index] } }
      ids = rows.map { |row| row[:id] }
      raise Refused, "an Activity ID is blank or not a number" unless ids.all? { |id| id.to_s.match?(/\A\d+\z/) }
      raise Refused, "an Activity ID appears twice" unless ids.uniq.size == ids.size

      rows
    rescue CSV::MalformedCSVError, ArgumentError, Track::TooLarge, Zip::Error => e
      raise Refused, "#{CSV_NAME} cannot be read (#{e.class.name})"
    end

    def column(header, key, name)
      indices = header.each_index.select { |index| header[index] == name }
      expected = TWICE.include?(key) ? 2 : 1
      raise Refused, "#{CSV_NAME} has #{name} #{indices.size} times, not #{expected}" unless indices.size == expected

      indices.last
    end

    # :created, :updated or :unchanged. Everything that can fail is read before
    # anything is written, so a failure leaves no partial entry behind.
    def import_row(zip, source, row)
      workout = Workout.where(source:).find_or_initialize_by(external_id: row[:id])
      return :unchanged if workout.published?

      workout.assign_attributes(actor: member.actor, occurred_at: occurred_at(row[:date]), data: data(row))
      track = track(zip, row[:filename])
      created = workout.new_record?

      # A save with nothing changed writes nothing, so a re-run leaves
      # updated_at alone; full_track_from uploads only bytes that differ.
      Workout.transaction do
        changed = workout.changed?
        workout.save!
        changed |= workout.full_track_from(track)

        created ? :created : (changed ? :updated : :unchanged)
      end
    end

    def occurred_at(date)
      ActiveSupport::TimeZone["UTC"].strptime(date.to_s, DATE_FORMAT)
    end

    def data(row)
      {
        "name" => row[:name].to_s,
        "activity_type" => self.class.activity_type(row[:type]),
        "source_activity_type" => row[:type].to_s,
        "distance_m" => number(row[:distance])&.round(1),
        "moving_time_s" => number(row[:moving_time])&.round,
        "elevation_gain_m" => number(row[:elevation_gain])&.round(1)
      }
    end

    # Blank is nil; anything else has to be a number.
    def number(value) = value.blank? ? nil : Float(value)

    # The whole ride, untrimmed, or an empty track for an activity with no file.
    def track(zip, filename)
      return Track.new([]) if filename.blank?

      format = FILENAME.match(filename)&.[](1) or raise UnsafeFilename, "not a file an export holds"
      entry = zip.find_entry(filename) or raise MissingFile, "not in the export"
      entry.get_input_stream { |io| Track.read(io, format:, limit:) }
    end
end
