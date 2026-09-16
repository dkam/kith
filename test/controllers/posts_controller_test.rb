require "test_helper"

class PostsControllerTest < ActionDispatch::IntegrationTest
  test "writing a post" do
    sign_in_as members(:alice)

    assert_difference -> { Post.count }, 1 do
      post posts_url, params: { post: { title: "A morning", body: "It **rained**.", audience: "followers" } }
    end

    written = Post.newest_first.first
    assert_redirected_to written
    assert_equal actors(:alice), written.actor
    assert_includes written.body_html, "<strong>rained</strong>"
  end

  test "writing a public post" do
    sign_in_as members(:alice)
    post posts_url, params: { post: { body: "Hello world", audience: "public" } }

    assert Post.newest_first.first.audience_public?
  end

  test "writing a post with photos" do
    sign_in_as members(:alice)

    post posts_url, params: { post: {
      body: "Two photos",
      photos: [ fixture_file_upload("landscape.jpg", "image/jpeg"), fixture_file_upload("portrait.jpg", "image/jpeg") ]
    } }

    assert_equal 2, Post.newest_first.first.photos.count
  end

  test "an empty post is refused" do
    sign_in_as members(:alice)

    assert_no_difference -> { Post.count } do
      post posts_url, params: { post: { title: "", body: "" } }
    end

    assert_response :unprocessable_content
  end

  test "the audience cannot be changed by editing" do
    sign_in_as members(:alice)
    target = posts(:alice_followers)

    patch post_url(target), params: { post: { body: "Edited", audience: "public" } }

    assert_redirected_to target
    assert target.reload.audience_followers?
    assert_includes target.body_html, "Edited"
  end

  test "deleting a post takes its photos with it" do
    sign_in_as members(:alice)
    target = posts(:alice_followers)
    target.photos.attach(io: file_fixture("landscape.jpg").open, filename: "landscape.jpg", content_type: "image/jpeg")

    assert_difference [ -> { Post.count }, -> { ActiveStorage::Attachment.count } ], -1 do
      delete post_url(target)
    end

    assert_redirected_to root_url
  end

  test "you cannot edit or delete someone else's post" do
    sign_in_as members(:bob)
    target = posts(:alice_followers)

    get edit_post_url(target)
    assert_response :not_found

    patch post_url(target), params: { post: { body: "Not mine to edit" } }
    assert_response :not_found

    assert_no_difference -> { Post.count } do
      delete post_url(target)
    end
    assert_response :not_found

    assert_equal "The long way round", target.reload.title
  end

  # --- Permalinks go through Visibility, like everything else ---

  test "a follower can read a followers-only permalink" do
    sign_in_as members(:bob)
    get post_url(posts(:alice_followers))

    assert_response :success
    assert_select "h1", "The long way round"
  end

  test "a stranger gets 404 for a followers-only permalink, not 403" do
    sign_in_as members(:dave)
    get post_url(posts(:alice_followers))

    assert_response :not_found
    assert_empty response.body
  end

  test "a signed-out visitor gets 404 for a followers-only permalink" do
    get post_url(posts(:alice_followers))
    assert_response :not_found
  end

  test "a signed-out visitor can read a public permalink" do
    get post_url(posts(:alice_public))

    assert_response :success
    assert_select "h1", "On keeping a notebook"
  end

  test "a post that does not exist gets the same 404 as one you may not see" do
    sign_in_as members(:dave)

    get post_url(id: 999_999)
    missing = response.status

    get post_url(posts(:alice_followers))
    assert_equal missing, response.status
  end

  test "photos on a permalink are rendered through MediaController" do
    posts(:alice_public).photos.attach(io: file_fixture("landscape.jpg").open, filename: "landscape.jpg", content_type: "image/jpeg")

    get post_url(posts(:alice_public))

    assert_select "img[src^='/media/']"
    assert_select "img[src*='/rails/active_storage/']", false
  end

  test "writing requires signing in" do
    get new_post_url
    assert_redirected_to new_session_url
  end
end
