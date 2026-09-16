require "test_helper"

class PostsControllerTest < ActionDispatch::IntegrationTest
  test "writing a post" do
    sign_in_as members(:alice)

    assert_difference -> { Post.count }, 1 do
      post posts_url, params: { post: { title: "A morning", body: "<p>It <strong>rained</strong>.</p>", audience: "followers" } }
    end

    written = Post.newest_first.first
    assert_redirected_to written
    assert_equal actors(:alice), written.actor
    assert_includes written.body.to_s, "<strong>rained</strong>"
  end

  test "writing a public post" do
    sign_in_as members(:alice)
    post posts_url, params: { post: { body: "<p>Hello world</p>", audience: "public" } }

    assert Post.newest_first.first.audience_public?
  end

  # Photos are uploaded by the editor before the form is submitted, so what
  # arrives here is markup naming two blobs that already exist.
  test "writing a post with photos" do
    sign_in_as members(:alice)
    blobs = [ photo_blob(filename: "landscape.jpg"), photo_blob(filename: "portrait.jpg") ]

    post posts_url, params: { post: {
      body: "<p>Two photos</p>#{blobs.map { |blob| attachment_markup(blob) }.join}"
    } }

    assert_equal 2, Post.newest_first.first.photos.count
  end

  # Lexxy previews an upload from its Active Storage blob URL and sends that URL
  # back with the post. It is a bearer token — it works for anyone holding it,
  # and it answers no question about who is asking — so it is dropped before the
  # body is stored, and never reaches a reader.
  test "the blob URL the editor sends is neither stored nor rendered" do
    sign_in_as members(:alice)
    blob = photo_blob
    blob_url = "/rails/active_storage/blobs/proxy/#{blob.signed_id}/#{blob.filename}"

    post posts_url, params: { post: {
      body: "<p>One photo</p>#{attachment_markup(blob, url: blob_url)}", audience: "public"
    } }

    written = Post.newest_first.first
    refute_includes written.body.body.to_html, blob_url
    refute_includes written.body.body.to_html, "/rails/active_storage/"

    get post_url(written)
    assert_select "img[src^='/media/']"
    assert_select "img[src*='/rails/active_storage/']", false
    refute_includes response.body, "/rails/active_storage/"
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

    patch post_url(target), params: { post: { body: "<p>Edited</p>", audience: "public" } }

    assert_redirected_to target
    assert target.reload.audience_followers?
    assert_includes target.body.to_s, "Edited"
  end

  test "deleting a post takes its photos with it" do
    sign_in_as members(:alice)
    target = posts(:alice_followers)
    embed_photo(target)

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

    patch post_url(target), params: { post: { body: "<p>Not mine to edit</p>" } }
    assert_response :not_found

    assert_no_difference -> { Post.count } do
      delete post_url(target)
    end
    assert_response :not_found

    assert_equal "The long way round", target.reload.title
  end

  # --- Moderation ---

  test "a moderator can delete a post they can see" do
    sign_in_as members(:mo)

    assert_difference -> { Post.count }, -1 do
      delete post_url(posts(:alice_public))
    end

    assert_redirected_to root_url
  end

  test "a moderator cannot delete a post they cannot see" do
    sign_in_as members(:mo)

    assert_no_difference -> { Post.count } do
      delete post_url(posts(:alice_followers))
    end

    assert_response :not_found
  end

  test "a moderator cannot edit someone else's post" do
    sign_in_as members(:mo)

    get edit_post_url(posts(:alice_public))
    assert_response :not_found

    patch post_url(posts(:alice_public)), params: { post: { title: "Rewritten by mo" } }
    assert_response :not_found

    assert_equal "On keeping a notebook", posts(:alice_public).reload.title
  end

  test "an ordinary member is offered no delete button on someone else's post" do
    sign_in_as members(:dave)
    get post_url(posts(:alice_public))

    assert_select "a[href=?]", edit_post_path(posts(:alice_public)), false
    assert_select "form[action=?]", post_path(posts(:alice_public)), false
  end

  test "a moderator is offered delete but not edit on someone else's post" do
    sign_in_as members(:mo)
    get post_url(posts(:alice_public))

    assert_select "a[href=?]", edit_post_path(posts(:alice_public)), false
    assert_select "form[action=?]", post_path(posts(:alice_public))
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
    embed_photo(posts(:alice_public))

    get post_url(posts(:alice_public))

    assert_select "img[src^='/media/']"
    assert_select "img[src*='/rails/active_storage/']", false
  end

  test "writing requires signing in" do
    get new_post_url
    assert_redirected_to new_session_url
  end
end
