require "test_helper"

# A direct upload names its file in the request, before any form of ours sees
# it. A Strava export's name is Strava's, and a photo's is often a date or a
# person, so `filename` is filtered: from the parameters, and from the SQL
# binds that write the blob row.
class DirectUploadLoggingTest < ActionDispatch::IntegrationTest
  SENTINEL = "sentinel-export-7448-do-not-log.zip"

  def logged
    io = StringIO.new
    logger = ActiveSupport::Logger.new(io).tap { _1.level = :debug }
    Rails.logger.broadcast_to(logger)
    yield
    io.string
  ensure
    Rails.logger.stop_broadcasting_to(logger)
  end

  test "a direct upload's filename never reaches the log" do
    sign_in_as members(:alice)

    log = logged do
      post rails_direct_uploads_url, as: :json, params: { blob: {
        filename: SENTINEL, byte_size: 2, checksum: Digest::MD5.base64digest("PK"), content_type: "application/zip"
      } }
    end

    assert_response :success
    assert_match "DirectUploadsController", log, "the request was not logged at all"
    assert_no_match SENTINEL.delete_suffix(".zip"), log
  end
end
