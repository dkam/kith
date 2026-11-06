require "test_helper"

# Direct upload is how a photo, an avatar and a Strava export reach storage:
# the browser asks for a blob, then PUTs the bytes to the URL it is handed.
# Asking for the blob is the step to guard, because nothing else hands out
# that URL (kith-web#11).
class DirectUploadsControllerTest < ActionDispatch::IntegrationTest
  test "signed out, a direct upload makes no blob and is sent to sign in" do
    assert_no_difference -> { ActiveStorage::Blob.count } do
      post rails_direct_uploads_url, params: upload, as: :json
    end

    assert_redirected_to new_session_url
    assert_nil response.parsed_body.try(:dig, "direct_upload")
  end

  test "signed in, a direct upload makes a blob and says where to put the bytes" do
    sign_in_as members(:alice)

    assert_difference -> { ActiveStorage::Blob.count }, 1 do
      post rails_direct_uploads_url, params: upload, as: :json
    end

    assert_response :success
    assert response.parsed_body.dig("direct_upload", "url").present?
  end

  private
    def upload(bytes = "a photograph")
      { blob: { filename: "photo.jpg", byte_size: bytes.bytesize,
        checksum: OpenSSL::Digest::MD5.base64digest(bytes), content_type: "image/jpeg" } }
    end
end
