require "test_helper"
require_relative "../test_helpers/strava_export_builder"

class StravaImportJobTest < ActiveJob::TestCase
  include StravaExportBuilder

  # Makes StravaExport#import raise what a test names, for the failures no
  # export can be built to cause. Inert unless `exploding` is running.
  module Explodes
    def import
      error = Thread.current[:strava_export_raises]
      error ? raise(error) : super
    end
  end
  StravaExport.prepend(Explodes)

  setup do
    @member = members(:alice)
    @dir = Dir.mktmpdir
  end

  teardown { FileUtils.remove_entry(@dir) }

  def import_of(path)
    blob = ActiveStorage::Blob.create_and_upload!(io: File.open(path), filename: "export_7448.zip",
      content_type: "application/zip")
    @member.strava_imports.create!(export: blob)
  end

  def exploding(error)
    Thread.current[:strava_export_raises] = error
    yield
  ensure
    Thread.current[:strava_export_raises] = nil
  end

  def assert_purged(import)
    blob_id = import.export.blob.id
    yield.tap do
      assert_not import.reload.export.attached?, "the import still holds its zip"
      assert_not ActiveStorage::Blob.exists?(blob_id), "the zip's blob is still in storage"
    end
  end

  test "an import that finishes records its counts and purges the zip" do
    import = import_of(export(rows: [ row(101), row(102, filename: "activities/102.tcx.gz"), row(103, filename: "activities/103.gpx") ],
      files: { "activities/101.gpx" => gpx, "activities/102.tcx.gz" => ActiveSupport::Gzip.compress(tcx),
               "activities/103.gpx" => "<gpx><trk" }))

    assert_purged(import) { StravaImportJob.perform_now(import.id) }

    assert import.done?
    assert_not_nil import.finished_at
    assert_equal({ "created" => 2, "updated" => 0, "unchanged" => 0, "removed" => 0,
      "failed" => [ [ "103", "Track::Malformed" ] ] }, import.result)
    assert_equal [ "103" ], import.failed_activity_ids
    assert_equal 2, @member.sources.strava_export.first.entries.count
  end

  test "a refused export records the refusal's message and purges the zip" do
    import = import_of(export(csv: csv([ row(101).values_at(0..10) ], header: HEADER.first(11))))

    assert_purged(import) { StravaImportJob.perform_now(import.id) }

    assert import.refused?
    assert_match "Filename", import.result["refused"]
    assert_equal [ "refused" ], import.result.keys
  end

  test "a file that is not a zip is refused, and purged" do
    import = import_of(File.join(@dir, "not.zip").tap { File.write(_1, "not a zip") })

    assert_purged(import) { StravaImportJob.perform_now(import.id) }

    assert_equal({ "refused" => "not a zip file" }, import.result)
  end

  # The message is the part that may carry a name or a coordinate, so it goes
  # nowhere: not into the row, and not into what is re-raised, which the error
  # report, the queue's failed executions and the job log all read.
  test "an unexpected exception fails the import, keeps only its class, purges the zip and re-raises" do
    import = import_of(export)
    secret = "Ride to 51.507351,-0.127758"

    error = assert_purged(import) do
      exploding(RuntimeError.new(secret)) do
        assert_raises(StravaImportJob::Failed) { StravaImportJob.perform_now(import.id) }
      end
    end

    assert import.failed?
    assert_equal({ "error" => "RuntimeError" }, import.result)
    assert_equal "RuntimeError", error.message
    assert_nil error.cause
    assert_not_empty error.backtrace
    assert_no_match secret, import.result.to_json
  end

  test "each change of state is broadcast to the member's own stream, and nobody else's" do
    import = import_of(export)

    assert_no_turbo_stream_broadcasts [ members(:bob), :strava_imports ] do
      assert_turbo_stream_broadcasts([ @member, :strava_imports ], count: 2) do # running, then done
        StravaImportJob.perform_now(import.id)
      end
    end
  end

  test "an import that is no longer queued is not run again" do
    import = import_of(export)
    import.update!(state: :done, finished_at: Time.current)

    StravaImportJob.perform_now(import.id)

    assert_nil @member.sources.strava_export.first
  end

  test "an import deleted while it waited is discarded" do
    import = import_of(export)
    import.destroy!

    assert_nothing_raised { StravaImportJob.perform_now(import.id) }
  end
end
