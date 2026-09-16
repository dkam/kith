require "test_helper"

class FollowsControllerTest < ActionDispatch::IntegrationTest
  test "asking to follow someone creates a requested edge" do
    sign_in_as members(:carol)

    assert_difference -> { Follow.count }, 1 do
      post follow_actor_url(actors(:bob))
    end

    assert Follow.between(actors(:carol), actors(:bob)).first.requested?
  end

  test "asking twice does not create a second edge" do
    sign_in_as members(:dave)

    assert_no_difference -> { Follow.count } do
      post follow_actor_url(actors(:alice))
    end
  end

  test "you cannot follow yourself" do
    sign_in_as members(:alice)

    assert_no_difference -> { Follow.count } do
      post follow_actor_url(actors(:alice))
    end
  end

  test "an invisible member cannot be followed by a stranger" do
    sign_in_as members(:dave)

    assert_no_difference -> { Follow.count } do
      post follow_actor_url(actors(:carol))
    end

    assert_response :not_found
  end

  test "accepting changes only this edge" do
    sign_in_as members(:alice)
    request = follows(:dave_follows_alice)

    assert_no_difference -> { Follow.count } do
      post accept_follow_url(request)
    end

    assert request.reload.accepted?
    assert_nil Follow.between(actors(:alice), actors(:dave)).first
  end

  test "accepting lets them read your posts, and does not let you read theirs" do
    sign_in_as members(:alice)
    post accept_follow_url(follows(:dave_follows_alice))

    assert Visibility.new(actors(:dave)).post?(posts(:alice_followers))
    refute Visibility.new(actors(:alice).reload).post?(posts(:dave_followers))
  end

  test "rejecting a request" do
    sign_in_as members(:alice)
    post reject_follow_url(follows(:dave_follows_alice))

    assert follows(:dave_follows_alice).reload.rejected?
  end

  test "only the followed actor may accept or reject" do
    sign_in_as members(:bob)

    post accept_follow_url(follows(:dave_follows_alice))
    assert_response :not_found

    post reject_follow_url(follows(:dave_follows_alice))
    assert_response :not_found

    assert follows(:dave_follows_alice).reload.requested?
  end

  test "unfollowing removes the edge outright" do
    sign_in_as members(:alice)

    assert_difference -> { Follow.count }, -1 do
      delete follow_url(follows(:alice_follows_carol))
    end

    assert_nil Follow.between(actors(:alice), actors(:carol)).first
  end

  test "unfollowing takes their posts with it" do
    sign_in_as members(:bob)
    assert Visibility.new(actors(:bob)).post?(posts(:alice_followers))

    delete follow_url(follows(:bob_follows_alice))

    refute Visibility.new(actors(:bob).reload).post?(posts(:alice_followers))
  end

  test "you cannot unfollow on someone else's behalf" do
    sign_in_as members(:carol)

    assert_no_difference -> { Follow.count } do
      delete follow_url(follows(:alice_follows_bob))
    end

    assert_response :not_found
  end

  test "cancelling your own pending request" do
    sign_in_as members(:dave)

    assert_difference -> { Follow.count }, -1 do
      delete follow_url(follows(:dave_follows_alice))
    end
  end

  # --- Turbo Streams ---

  test "following responds with a stream that replaces the button" do
    sign_in_as members(:carol)

    post follow_actor_url(actors(:bob)), as: :turbo_stream

    assert_response :success
    assert_equal Mime[:turbo_stream], response.media_type
    assert_match %r{<turbo-stream action="replace" target="#{dom_id(actors(:bob), :follow_button)}"}, response.body
    assert_match "Asked", response.body
  end

  test "unfollowing responds with a stream showing the plain follow button again" do
    sign_in_as members(:alice)

    delete follow_url(follows(:alice_follows_carol)), as: :turbo_stream

    assert_match %r{<turbo-stream action="replace" target="#{dom_id(actors(:carol), :follow_button)}"}, response.body
    assert_match ">Follow<", response.body
  end

  test "accepting responds with a stream offering to follow back" do
    sign_in_as members(:alice)

    post accept_follow_url(follows(:dave_follows_alice)), as: :turbo_stream

    assert_match "follows you now", response.body
    assert_match ">Follow<", response.body
    assert_match "follow-requests-heading", response.body
  end

  test "rejecting responds with a stream that removes the row" do
    sign_in_as members(:alice)

    post reject_follow_url(follows(:dave_follows_alice)), as: :turbo_stream

    assert_match %r{<turbo-stream action="remove" target="#{dom_id(follows(:dave_follows_alice), :request)}"}, response.body
  end

  test "without turbo the same actions redirect back" do
    sign_in_as members(:carol)

    post follow_actor_url(actors(:bob)), headers: { "Referer" => profile_url(actors(:bob).handle) }

    assert_redirected_to profile_url(actors(:bob).handle)
  end

  test "following requires signing in" do
    post follow_actor_url(actors(:alice))
    assert_redirected_to new_session_url
  end
end
