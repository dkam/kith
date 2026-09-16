require "test_helper"

# Almost every time Kith shows is relative — "3 hours ago" needs no zone at all.
# The absolute ones do, and they are the reader's own: a request is wrapped in
# the member's zone, so the same post is 9pm to one friend and 11pm to another.
class MemberTimeZoneTest < ActionDispatch::IntegrationTest
  test "absolute times are rendered in the reader's own zone" do
    members(:bob).update!(time_zone: "Melbourne")
    sign_in_as members(:bob)

    get post_url(posts(:alice_public))

    assert_response :success
    assert_select "time[title=?]", posts(:alice_public).published_at.in_time_zone("Melbourne").to_fs(:long)
  end

  test "two readers of the same post see two different clocks" do
    members(:bob).update!(time_zone: "Melbourne")
    members(:dave).update!(time_zone: "London")

    sign_in_as members(:bob)
    get post_url(posts(:alice_public))
    melbourne = css_select("time").first["title"]

    sign_out
    sign_in_as members(:dave)
    get post_url(posts(:alice_public))

    refute_equal melbourne, css_select("time").first["title"]
  end

  test "a member who has chosen no zone gets the instance's" do
    sign_in_as members(:bob)

    get post_url(posts(:alice_public))

    assert_select "time[title=?]", posts(:alice_public).published_at.in_time_zone(Rails.application.config.time_zone).to_fs(:long)
  end

  test "a signed-out visitor gets the instance's zone" do
    get post_url(posts(:alice_public))

    assert_response :success
    assert_select "time[title=?]", posts(:alice_public).published_at.in_time_zone(Rails.application.config.time_zone).to_fs(:long)
  end

  test "an invented zone on a member cannot take a request down with it" do
    members(:bob).update_column(:time_zone, "Middle Earth")
    sign_in_as members(:bob)

    get post_url(posts(:alice_public))

    assert_response :success
  end
end
