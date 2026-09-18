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

  test "a signed-out visitor gets 404 for every profile but one on the web" do
    get profile_url("bob")
    assert_response :not_found

    get profile_url("alice")
    assert_response :not_found

    get profile_url("carol")
    assert_response :not_found

    get profile_url("erin")
    assert_response :success
  end

  test "a hidden profile and a handle nobody has are the same 404 to a stranger" do
    get profile_url("nobody")
    unknown = response.status

    get profile_url("bob")
    assert_equal unknown, response.status
  end

  test "the web sees only public posts on a profile, and none of the graph" do
    erin = actors(:erin)
    public_post = erin.posts.create!(title: "In the open", audience: :public, body: "<p>Anyone.</p>")
    private_post = erin.posts.create!(title: "Not in the open", audience: :followers, body: "<p>Only some.</p>")

    get profile_url("erin")

    assert_response :success
    assert_select "##{dom_id(public_post)}"
    assert_select "##{dom_id(private_post)}", false
    assert_select "##{dom_id(erin, :follow_button)}", false
    assert_select "p", { text: "Follows you", count: 0 }
    assert_no_match(/Followers/i, response.body)
  end

  test "the anonymous profile is cacheable, and the members' one never is" do
    get profile_url("erin")
    assert_match "public", response.headers["Cache-Control"]

    sign_in_as members(:bob)
    get profile_url("erin")
    assert_no_match(/public/, response.headers["Cache-Control"].to_s)
  end

  test "a member still sees the full profile of someone on the web" do
    sign_in_as members(:bob)
    get profile_url("erin")

    assert_response :success
    assert_select "##{dom_id(actors(:erin), :follow_button)}"
  end

  test "handles are case insensitive" do
    sign_in_as members(:bob)
    get profile_url("ALICE")

    assert_response :success
  end
end
