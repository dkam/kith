require "csv"

# Builds a Strava account export on the fly, from the invented tracks in
# test/fixtures/files/tracks, with a CSV laid out the way Strava lays it out:
# Distance twice, in km and then in metres, and the columns Kith must never
# read sitting between the ones it does.
#
# The zip is written into @dir, which the including test makes and removes.
module StravaExportBuilder
  TRACKS = Rails.root.join("test/fixtures/files/tracks")

  HEADER = [ "Activity ID", "Activity Date", "Activity Name", "Activity Type", "Activity Description",
    "Elapsed Time", "Distance", "Max Heart Rate", "Commute", "Activity Private Note", "Activity Gear",
    "Filename", "Athlete Weight", "Elapsed Time", "Moving Time", "Distance", "Elevation Gain", "Calories" ].freeze

  # One CSV row, Strava's way. Every value is overridable by column name;
  # :distance_km and :distance_m are the two Distance columns.
  def row(id, filename: "activities/#{id}.gpx", **values)
    defaults = {
      "Activity ID" => id.to_s, "Activity Date" => "Sep 19, 2026, 4:23:34 AM", "Activity Name" => "Ride #{id}",
      "Activity Type" => "Ride", "Activity Description" => "description #{id}", "Max Heart Rate" => "171.0",
      "Commute" => "false", "Activity Private Note" => "private note #{id}", "Activity Gear" => "the bike",
      "Filename" => filename, "Athlete Weight" => "80.0", "Moving Time" => "1235.0", "Elevation Gain" => "19.2",
      "Calories" => "400"
    }.merge(values.transform_keys(&:to_s))

    HEADER.each_with_index.map do |name, index|
      case [ name, index ]
      in [ "Distance", 6 ] then values.fetch(:distance_km, "3.33")
      in [ "Distance", _ ] then values.fetch(:distance_m, "3331.3")
      in [ "Elapsed Time", _ ] then "1262"
      else defaults.fetch(name)
      end
    end
  end

  def csv(rows, header: HEADER) = CSV.generate { |out| ([ header ] + rows).each { |r| out << r } }

  def export(rows: [ row(101), row(102, filename: "activities/102.tcx.gz") ], csv: nil, files: nil, name: "export.zip")
    files ||= { "activities/101.gpx" => gpx, "activities/102.tcx.gz" => ActiveSupport::Gzip.compress(tcx) }
    path = File.join(@dir, name)
    File.delete(path) if File.exist?(path)

    Zip::File.open(path, create: true) do |zip|
      zip.get_output_stream("activities.csv") { |out| out.write(csv || self.csv(rows)) }
      files.each { |entry, data| zip.get_output_stream(entry) { |out| out.write(data) } }
    end

    path
  end

  def gpx = TRACKS.join("ride.gpx").read
  def tcx = TRACKS.join("ride.tcx").read
end
