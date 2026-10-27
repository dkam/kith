require "test_helper"

class PurgeUnattachedBlobsJobTest < ActiveJob::TestCase
  def blob(created_at: Time.current)
    ActiveStorage::Blob.create_and_upload!(io: StringIO.new("PK"), filename: "export.zip",
      content_type: "application/zip").tap { _1.update_column(:created_at, created_at) }
  end

  test "an unattached blob older than a day is purged; a newer one, and an attached one, stay" do
    old = blob(created_at: 25.hours.ago)
    recent = blob(created_at: 23.hours.ago)
    attached = blob(created_at: 2.days.ago)
    members(:alice).strava_imports.create!(export: attached)

    PurgeUnattachedBlobsJob.perform_now

    assert_not ActiveStorage::Blob.exists?(old.id)
    assert ActiveStorage::Blob.exists?(recent.id)
    assert ActiveStorage::Blob.exists?(attached.id)
  end

  # The file goes from storage, not just the row.
  test "purging deletes the file itself" do
    old = blob(created_at: 2.days.ago)

    PurgeUnattachedBlobsJob.perform_now

    assert_not old.service.exist?(old.key)
  end

  # A process that died mid-import never reached the job's ensure. Without
  # this the member could never import again, and the zip would stay.
  test "an import stalled for a day is failed and its zip purged; one still running is left alone" do
    stalled = members(:alice).strava_imports.create!(export: blob, state: :running)
    stalled.update_column(:updated_at, 25.hours.ago)
    running = members(:bob).strava_imports.create!(export: blob, state: :running)

    PurgeUnattachedBlobsJob.perform_now

    assert stalled.reload.failed?
    assert_equal({ "error" => "StravaImport::Stalled" }, stalled.result)
    assert_not stalled.export.attached?
    assert running.reload.running?
    assert running.export.attached?
  end
end
