require "application_system_test_case"
require_relative "../test_helpers/strava_export_builder"

class ImportingFromStravaTest < ApplicationSystemTestCase
  include ActiveJob::TestHelper
  include StravaExportBuilder

  setup do
    @member = members(:alice)
    @dir = Dir.mktmpdir
    sign_in_as @member
  end

  teardown { FileUtils.remove_entry(@dir) }

  test "importing an export from settings: the counts arrive by themselves, and the zip is gone" do
    path = export(rows: [ row(101), row(102, filename: "activities/102.tcx.gz"), row(103, filename: "activities/103.gpx") ],
      files: { "activities/101.gpx" => gpx, "activities/102.tcx.gz" => ActiveSupport::Gzip.compress(tcx),
               "activities/103.gpx" => "<gpx><trk" })
    blobs_before = ActiveStorage::Blob.count

    visit settings_path
    click_on "Import from Strava"
    attach_file "Your Strava export", path
    click_on "Import"

    assert_text "Waiting to start.", wait: 15
    # The page is subscribed before the job runs, so what follows arrives by
    # Turbo Stream rather than by a reload.
    assert_selector "turbo-cable-stream-source[connected]", visible: :all, wait: 5
    perform_enqueued_jobs(only: StravaImportJob)

    within "#latest_strava_import" do
      assert_text "Finished", wait: 10
      assert_selector "#strava_import_created", text: "2"
      assert_selector "#strava_import_failed li", text: "103"
    end
    assert_current_path settings_strava_import_path

    assert_equal 2, @member.sources.strava_export.first.entries.count
    import = @member.strava_imports.sole
    assert_not import.export.attached?
    # Two tracks were attached; the zip came and went.
    assert_equal blobs_before + 2, ActiveStorage::Blob.count
    assert_empty ActiveStorage::Blob.unattached
  end

  # Active Storage calls alert() on a failed upload unless the page stops it,
  # and a large upload cut off by a proxy would end in a browser dialog. An
  # open dialog fails the next thing Selenium does, so reaching the
  # assertions at all says there was none.
  test "an upload that fails says so on the page, with no dialog and no import" do
    visit settings_strava_import_path
    page.execute_script(<<~JS)
      document.querySelector("input[type=file]").dataset.directUploadUrl = "/rails/active_storage/nowhere"
    JS
    attach_file "Your Strava export", export
    click_on "Import"

    assert_text "The upload didn't finish. Try again.", wait: 10
    assert_current_path settings_strava_import_path
    assert_empty @member.strava_imports
  end
end
