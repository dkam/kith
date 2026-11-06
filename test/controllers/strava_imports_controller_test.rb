require "test_helper"
require_relative "../test_helpers/strava_export_builder"

class StravaImportsControllerTest < ActionDispatch::IntegrationTest
  include ActiveJob::TestHelper
  include StravaExportBuilder

  setup do
    @member = members(:alice)
    @dir = Dir.mktmpdir
    sign_in_as @member
  end

  teardown { FileUtils.remove_entry(@dir) }

  # What direct upload leaves in storage before the form is submitted.
  def uploaded(path = export)
    ActiveStorage::Blob.create_and_upload!(io: File.open(path), filename: "export_7448.zip",
      content_type: "application/zip")
  end

  def start(blob) = post settings_strava_import_url, params: { strava_import: { export: blob&.signed_id } }

  test "signed out, the page and the form both send you to sign in" do
    sign_out

    get settings_strava_import_url
    assert_redirected_to new_session_url

    blob = uploaded
    assert_no_enqueued_jobs(only: StravaImportJob) { start(blob) }
    assert_redirected_to new_session_url
  end

  test "the page shows the form, and the settings page links to it" do
    get settings_url
    assert_select "a[href=?]", settings_strava_import_path

    get settings_strava_import_url
    assert_response :success
    assert_select "input[type=file][name='strava_import[export]'][data-direct-upload-url]"
  end

  test "an upload starts an import, whose job is given its id and nothing else" do
    blob = uploaded

    assert_difference -> { @member.strava_imports.count } do
      start(blob)
    end

    import = @member.strava_imports.sole
    assert_redirected_to settings_strava_import_url
    assert import.queued?
    assert_equal blob, import.export.blob
    assert_enqueued_with job: StravaImportJob, args: [ import.id ]
  end

  test "the page shows the latest import's counts and failed activity ids, and nothing from the zip" do
    @member.strava_imports.create!(export: uploaded, state: :done, finished_at: 1.minute.ago,
      result: { created: 3, updated: 1, unchanged: 40, removed: 0, failed: [ [ "9876", "Track::Malformed" ] ] })

    get settings_strava_import_url

    assert_select "#latest_strava_import #strava_import_created", "3"
    assert_select "#latest_strava_import #strava_import_unchanged", "40"
    assert_select "#strava_import_failed li", "9876"
    assert_no_match "export_7448", response.body
    assert_no_match "Track::Malformed", response.body
  end

  test "a member sees only their own imports" do
    members(:bob).strava_imports.create!(export: uploaded, state: :refused, finished_at: 1.minute.ago,
      result: { refused: "no activities.csv in the export" })

    get settings_strava_import_url

    assert_select "#latest_strava_import", text: /./, count: 0
    assert_no_match "activities.csv in the export", response.body
  end

  test "the page subscribes to a stream signed for this member" do
    get settings_strava_import_url

    signed = css_select("turbo-cable-stream-source").first["signed-stream-name"]
    assert_equal Turbo::StreamsChannel.signed_stream_name([ @member, :strava_imports ]), signed
  end

  test "a second import while one runs is refused, and its upload purged" do
    @member.strava_imports.create!(export: uploaded, state: :running)
    blob = uploaded

    assert_no_enqueued_jobs(only: StravaImportJob) { start(blob) }

    assert_response :unprocessable_content
    assert_match StravaImport::ALREADY_RUNNING, response.body
    assert_not ActiveStorage::Blob.exists?(blob.id)
  end

  test "another member's running import does not stop yours" do
    members(:bob).strava_imports.create!(export: uploaded, state: :running)

    assert_enqueued_with(job: StravaImportJob) { start(uploaded) }
  end

  test "an upload over the cap is purged and refused, with nothing enqueued" do
    blob = uploaded
    blob.update_column(:byte_size, StravaImport::MAX_BYTES + 1)

    assert_no_enqueued_jobs(only: StravaImportJob) do
      assert_no_difference(-> { StravaImport.count }) { start(blob) }
    end

    assert_response :unprocessable_content
    assert_match "larger than 2 GB", response.body
    assert_not ActiveStorage::Blob.exists?(blob.id)
  end

  test "no upload, or a signed id that does not verify, is refused" do
    assert_no_enqueued_jobs(only: StravaImportJob) do
      start(nil)
      assert_response :unprocessable_content

      post settings_strava_import_url, params: { strava_import: { export: "not-a-signed-id" } }
      assert_response :unprocessable_content
    end
  end

  # The job purges the zip when it ends, so a blob already attached somewhere
  # — a photo in a post — must never be taken for one, or the photo goes.
  test "a blob that is already attached to something is never taken for an upload" do
    photo = uploaded.tap { |blob| actors(:alice).avatar.attach(blob) }

    assert_no_enqueued_jobs(only: StravaImportJob) { start(photo) }

    assert_response :unprocessable_content
    assert ActiveStorage::Blob.exists?(photo.id)
    assert actors(:alice).reload.avatar.attached?
  end
end
