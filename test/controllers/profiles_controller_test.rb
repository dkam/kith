require "test_helper"

class ProfilesControllerTest < ActionDispatch::IntegrationTest
  test "a profile shows the posts you are allowed to see and no others" do
    sign_in_as members(:bob)
    get profile_url("alice")

    assert_response :success
    assert_select "##{dom_id(posts(:alice_followers))}"
    assert_select "##{dom_id(posts(:alice_public))}"
  end

  test "a stranger sees only the public posts on a profile" do
    sign_in_as members(:dave)
    get profile_url("alice")

    assert_response :success
    assert_select "##{dom_id(posts(:alice_public))}"
    assert_select "##{dom_id(posts(:alice_followers))}", false
  end

  test "an invisible member's profile is 404 for a stranger" do
    sign_in_as members(:dave)
    get profile_url("carol")

    assert_response :not_found
  end

  test "an invisible member can see their own profile" do
    sign_in_as members(:carol)
    get profile_url("carol")

    assert_response :success
  end

  test "an unknown handle gets the same 404 as a hidden one" do
    sign_in_as members(:dave)

    get profile_url("nobody")
    unknown = response.status

    get profile_url("carol")
    assert_equal unknown, response.status
  end

  test "the follow button reflects the state of the edge" do
    sign_in_as members(:dave)
    get profile_url("alice")
    assert_select "##{dom_id(actors(:alice), :follow_button)}", /Asked/

    sign_out
    sign_in_as members(:bob)
    get profile_url("alice")
    assert_select "##{dom_id(actors(:alice), :follow_button)}", /Following/
  end

  test "there is no follow button on your own profile" do
    sign_in_as members(:alice)
    get profile_url("alice")

    assert_select "##{dom_id(actors(:alice), :follow_button)}", false
  end

  test "'follows you' is shown only when they actually do" do
    sign_in_as members(:alice)

    get profile_url("bob")
    assert_select "p", "Follows you"

    get profile_url("carol")
    assert_select "p", { text: "Follows you", count: 0 }
  end

  test "a signed-out visitor has no profiles at all" do
    get profile_url("bob")
    assert_redirected_to new_session_url
  end

  test "handles are case insensitive" do
    sign_in_as members(:bob)
    get profile_url("ALICE")

    assert_response :success
  end
end
