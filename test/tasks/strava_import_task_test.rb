require "test_helper"

class StravaImportTaskTest < ActiveSupport::TestCase
  setup do
    Rails.application.load_tasks unless Rake::Task.task_defined?("kith:strava_import")
    @dir = Dir.mktmpdir
  end

  teardown do
    Rake::Task["kith:strava_import"].reenable
    FileUtils.remove_entry(@dir)
  end

  def run_task(*args)
    capture_io { Rake::Task["kith:strava_import"].invoke(*args) }
  end

  def export(csv)
    File.join(@dir, "export.zip").tap do |path|
      Zip::File.open(path, create: true) do |zip|
        zip.get_output_stream("activities.csv") { |out| out.write(csv) }
        zip.get_output_stream("activities/101.gpx") { |out| out.write(file_fixture("tracks/ride.gpx").read) }
      end
    end
  end

  HEADER = "Activity ID,Activity Date,Activity Name,Activity Type,Distance,Filename,Moving Time,Distance,Elevation Gain\n"

  test "it prints the counts and the failed ids, and never a name or a coordinate" do
    path = export(HEADER + %(101,"Sep 19, 2026, 4:23:34 AM",Secret Name,Ride,3.33,activities/101.gpx,1235.0,3331.3,19.2\n) +
      %(102,"Sep 19, 2026, 4:23:34 AM",Other Name,Ride,3.33,activities/102.gpx,1235.0,3331.3,19.2\n))

    out, = run_task("alice@example.com", path)

    assert_equal "1 created, 0 updated, 0 unchanged, 0 removed, 1 failed\n  failed: 102 (StravaExport::MissingFile)\n", out
    assert File.exist?(path), "the zip is left where it was"
  end

  test "a refused import says why, and writes nothing" do
    path = export(HEADER.sub(",Filename", ",File") + %(101,"Sep 19, 2026, 4:23:34 AM",Secret Name,Ride,3.33,x,1,2,3\n))

    assert_no_difference "Entry.count" do
      error = assert_raises(SystemExit) { run_task("@alice", path) }
      refute error.success?
    end
  end

  test "an unknown member is refused" do
    assert_raises(SystemExit) { run_task("nobody@example.com", export(HEADER)) }
  end
end
