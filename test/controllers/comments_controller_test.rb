require "test_helper"

class CommentsControllerTest < ActionDispatch::IntegrationTest
  test "replying to a post you can see" do
    sign_in_as members(:bob)

    assert_difference -> { Comment.count }, 1 do
      post post_comments_url(posts(:alice_followers)), params: { comment: { body: "Quite." } }
    end

    assert_equal actors(:bob), Comment.order(:id).last.actor
  end

  test "you cannot reply to a post you cannot see" do
    sign_in_as members(:dave)

    assert_no_difference -> { Comment.count } do
      post post_comments_url(posts(:alice_followers)), params: { comment: { body: "Sneaking in" } }
    end

    assert_response :not_found
  end

  test "a signed-out visitor cannot reply to a public post" do
    assert_no_difference -> { Comment.count } do
      post post_comments_url(posts(:alice_public)), params: { comment: { body: "Hello" } }
    end

    assert_redirected_to new_session_url
  end

  test "an empty reply is refused" do
    sign_in_as members(:bob)

    assert_no_difference -> { Comment.count } do
      post post_comments_url(posts(:alice_followers)), params: { comment: { body: "  " } }, as: :turbo_stream
    end

    assert_response :unprocessable_content
  end

  test "deleting your own reply" do
    sign_in_as members(:bob)

    assert_difference -> { Comment.count }, -1 do
      delete comment_url(comments(:bob_on_alice_followers))
    end
  end

  test "the post's author can delete any reply on it" do
    sign_in_as members(:alice)

    assert_difference -> { Comment.count }, -1 do
      delete comment_url(comments(:bob_on_alice_followers))
    end
  end

  test "you cannot delete someone else's reply on someone else's post" do
    sign_in_as members(:bob)

    assert_no_difference -> { Comment.count } do
      delete comment_url(comments(:alice_on_alice_followers))
    end

    assert_response :not_found
  end

  # --- The gated profile link -----------------------------------------------

  test "a commenter's name is always shown" do
    sign_in_as members(:bob)
    get post_url(posts(:alice_followers))

    assert_select "##{dom_id(comments(:bob_on_alice_followers))}", /Bob Ndlovu/
  end

  test "a discoverable commenter's name links to their profile" do
    sign_in_as members(:dave)
    get post_url(posts(:alice_public))

    assert_select "##{dom_id(comments(:bob_on_alice_public))} a[href=?]", profile_path("bob")
  end

  test "a connections-only commenter's name is shown but not linked to a stranger" do
    comment = posts(:alice_public).comments.create!(actor: actors(:alice), body: "My own post")

    sign_in_as members(:dave)
    get post_url(posts(:alice_public))

    assert_select "##{dom_id(comment)}", /Alice Brennan/
    assert_select "##{dom_id(comment)} a[href=?]", profile_path("alice"), false
  end

  test "a connections-only commenter's name links for their connection" do
    comment = posts(:alice_public).comments.create!(actor: actors(:alice), body: "My own post")

    sign_in_as members(:bob)
    get post_url(posts(:alice_public))

    assert_select "##{dom_id(comment)} a[href=?]", profile_path("alice")
  end

  # --- Invisible commenters -------------------------------------------------

  test "an invisible member's reply is hidden from everyone but their connections" do
    sign_in_as members(:bob)
    get post_url(posts(:alice_followers))

    assert_select "##{dom_id(comments(:bob_on_alice_followers))}"
    assert_select "##{dom_id(comments(:carol_on_alice_followers))}", false
  end

  test "an invisible member's reply on a public post is hidden from a signed-out visitor" do
    get post_url(posts(:alice_public))

    assert_response :success
    assert_select "##{dom_id(comments(:bob_on_alice_public))}"
    assert_select "##{dom_id(comments(:carol_on_alice_public))}", false
  end

  test "an invisible member sees their own reply" do
    sign_in_as members(:carol)
    get post_url(posts(:alice_public))

    assert_select "##{dom_id(comments(:carol_on_alice_public))}"
  end

  test "the reply count matches what is actually shown" do
    sign_in_as members(:bob)
    get post_url(posts(:alice_followers))

    shown = css_select("li[id^='comment_']").size
    assert_select "h2", "#{shown} replies"
  end

  # --- Turbo Streams --------------------------------------------------------

  test "replying appends the reply and clears the box" do
    sign_in_as members(:bob)

    post post_comments_url(posts(:alice_followers)), params: { comment: { body: "Turbo reply" } }, as: :turbo_stream

    assert_response :success
    assert_match %r{<turbo-stream action="append" target="#{dom_id(posts(:alice_followers), :comments)}"}, response.body
    assert_match "Turbo reply", response.body
    assert_match %r{<turbo-stream action="replace" target="#{dom_id(posts(:alice_followers), :comment_form)}"}, response.body
  end

  test "deleting responds with a stream that removes the reply" do
    sign_in_as members(:bob)

    delete comment_url(comments(:bob_on_alice_followers)), as: :turbo_stream

    assert_match %r{<turbo-stream action="remove" target="#{dom_id(comments(:bob_on_alice_followers))}"}, response.body
  end
end
