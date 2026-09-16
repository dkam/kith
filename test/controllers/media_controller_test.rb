require "test_helper"

class MediaControllerTest < ActionDispatch::IntegrationTest
  setup do
    @private_post = posts(:alice_followers)
    @private_post.photos.attach(io: file_fixture("landscape.jpg").open, filename: "landscape.jpg", content_type: "image/jpeg")
    @private_photo = @private_post.photos.first

    @public_post = posts(:alice_public)
    @public_post.photos.attach(io: file_fixture("landscape.jpg").open, filename: "landscape.jpg", content_type: "image/jpeg")
    @public_photo = @public_post.photos.first
  end

  test "the author can fetch their own photo" do
    sign_in_as members(:alice)
    get media_url(signed(@private_photo), :feed)

    assert_response :success
    assert_equal "image/jpeg", response.media_type
  end

  test "an accepted follower can fetch it" do
    sign_in_as members(:bob)
    get media_url(signed(@private_photo), :feed)

    assert_response :success
  end

  test "a pending follower gets 404, not 403" do
    sign_in_as members(:dave)
    get media_url(signed(@private_photo), :feed)

    assert_response :not_found
    assert_empty response.body
  end

  test "a stranger gets 404" do
    sign_in_as members(:carol)
    get media_url(signed(@private_photo), :feed)

    assert_response :not_found
  end

  test "a signed-out visitor gets 404 for a private photo" do
    get media_url(signed(@private_photo), :feed)
    assert_response :not_found
  end

  test "a signed-out visitor can fetch a public post's photo" do
    get media_url(signed(@public_photo), :feed)
    assert_response :success
  end

  test "losing access loses the photo with it" do
    sign_in_as members(:bob)
    get media_url(signed(@private_photo), :feed)
    assert_response :success

    follows(:bob_follows_alice).reject!

    get media_url(signed(@private_photo), :feed)
    assert_response :not_found
  end

  test "private media is never cached" do
    sign_in_as members(:alice)
    get media_url(signed(@private_photo), :feed)

    assert_equal "private, no-store", response.headers["Cache-Control"]
    assert_includes response.headers["Vary"].to_s, "Cookie"
  end

  test "public media may be cached" do
    get media_url(signed(@public_photo), :feed)

    assert_includes response.headers["Cache-Control"], "public"
    refute_includes response.headers["Cache-Control"], "no-store"
  end

  test "all three variants are served" do
    sign_in_as members(:alice)

    %w[ thumb feed full ].each do |variant|
      get media_url(signed(@private_photo), variant)
      assert_response :success, "expected the #{variant} variant to be served"
    end
  end

  test "an invented variant is not routable" do
    sign_in_as members(:alice)

    assert_raises ActionController::UrlGenerationError do
      get media_url(signed(@private_photo), "original")
    end
  end

  test "a forged signed id gets 404" do
    sign_in_as members(:alice)
    get media_url("not-a-real-signed-id", :feed)

    assert_response :not_found
  end

  test "a signed id for a deleted attachment gets 404" do
    sign_in_as members(:alice)
    signed_id = signed(@private_photo)
    @private_post.destroy

    get media_url(signed_id, :feed)
    assert_response :not_found
  end

  test "avatars are visible to any member and to no one else" do
    actors(:carol).avatar.attach(io: file_fixture("portrait.jpg").open, filename: "portrait.jpg", content_type: "image/jpeg")
    signed_id = signed(actors(:carol).avatar.attachment)

    sign_in_as members(:dave)
    get media_url(signed_id, :thumb)
    assert_response :success

    sign_out
    get media_url(signed_id, :thumb)
    assert_response :not_found
  end

  test "served variants carry no EXIF, so no GPS coordinates leave the server" do
    sign_in_as members(:alice)
    get media_url(signed(@private_photo), :full)

    assert_response :success
    refute_includes response.body, "Kith Test Camera"
    refute_includes response.body[0, 4096], "Exif"
  end

  test "no blob URL is ever generated for an attachment" do
    assert_match %r{\A/media/}, MediaHelperProbe.new.media_url_for(@private_photo)
  end

  private
    def signed(attachment)
      AttachableMedia.signed_id(attachment)
    end

    class MediaHelperProbe
      include MediaHelper
      include Rails.application.routes.url_helpers
    end
end
