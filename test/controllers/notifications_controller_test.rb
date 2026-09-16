require "test_helper"

class NotificationsControllerTest < ActionDispatch::IntegrationTest
  test "a new follower is announced" do
    sign_in_as members(:carol)
    post follow_actor_url(actors(:bob))
    sign_out

    sign_in_as members(:bob)
    get notifications_url

    assert_response :success
    assert_select "li", /Carol Iyer asked to follow you/
  end

  test "an accepted follow is announced to the follower" do
    sign_in_as members(:alice)
    post accept_follow_url(follows(:dave_follows_alice))
    sign_out

    sign_in_as members(:dave)
    get notifications_url

    assert_select "li", /Alice Brennan accepted your follow/
  end

  test "a reply is announced to the post's author" do
    posts(:alice_followers).comments.create!(actor: actors(:bob), body: "Good road")

    sign_in_as members(:alice)
    get notifications_url

    assert_select "li", /Bob Ndlovu replied to/
  end

  # --- The side channel -----------------------------------------------------

  test "a notification about something you may no longer see is not shown" do
    comment = posts(:alice_followers).comments.create!(actor: actors(:bob), body: "Visible for now")
    notification = members(:alice).notifications.find_by(subject: comment)
    assert notification

    # Bob becomes invisible and is not connected to Alice any more, so his
    # comment is no longer hers to see — and neither is the notification.
    follows(:bob_follows_alice).reject!
    actors(:bob).update!(discoverable: :invisible)

    sign_in_as members(:alice)
    get notifications_url

    assert_select "##{dom_id(notification)}", false
  end

  test "notifications apply the identical check as the feed" do
    comment = posts(:alice_followers).comments.create!(actor: actors(:carol), body: "From an invisible member")
    notification = members(:alice).notifications.find_by(subject: comment)
    assert notification, "the notification is delivered"

    policy = Visibility.new(actors(:alice))
    refute policy.comment?(comment), "but Alice may not see Carol's comment"
    refute policy.notification?(notification), "so she may not see the notification either"

    sign_in_as members(:alice)
    get notifications_url
    assert_select "##{dom_id(notification)}", false
  end

  test "you never see someone else's notifications" do
    posts(:alice_followers).comments.create!(actor: actors(:bob), body: "For Alice")

    sign_in_as members(:bob)
    get notifications_url

    assert_select "li", false
    assert_select "p", /Nothing to tell you/
  end

  test "the unread badge counts only what you can see" do
    posts(:alice_followers).comments.create!(actor: actors(:carol), body: "Hidden from Alice")

    sign_in_as members(:alice)
    get root_url

    assert_select "#alert", false
    assert_select "span.bg-accent", false, "an invisible member's reply must not be counted in the badge"
  end

  test "the unread badge counts what you can see" do
    posts(:alice_followers).comments.create!(actor: actors(:bob), body: "Visible to Alice")

    sign_in_as members(:alice)
    get root_url

    assert_select "header span", "1"
  end

  # --- Reading --------------------------------------------------------------

  test "opening a reply notification marks it read and goes to the reply" do
    comment = posts(:alice_followers).comments.create!(actor: actors(:bob), body: "Take me there")
    notification = members(:alice).notifications.find_by(subject: comment)

    sign_in_as members(:alice)
    patch notification_url(notification)

    assert_redirected_to post_path(posts(:alice_followers), anchor: dom_id(comment))
    assert notification.reload.read?
  end

  test "opening a follow notification goes to the following page" do
    sign_in_as members(:carol)
    post follow_actor_url(actors(:bob))
    sign_out

    notification = members(:bob).notifications.last

    sign_in_as members(:bob)
    patch notification_url(notification)

    assert_redirected_to follows_path
  end

  test "you cannot mark someone else's notification read" do
    posts(:alice_followers).comments.create!(actor: actors(:bob), body: "For Alice")
    notification = members(:alice).notifications.last

    sign_in_as members(:bob)
    patch notification_url(notification)

    assert_response :not_found
    refute notification.reload.read?
  end

  test "marking everything read" do
    posts(:alice_followers).comments.create!(actor: actors(:bob), body: "One")

    sign_in_as members(:alice)
    post read_all_notifications_url

    assert_redirected_to notifications_url
    assert_empty members(:alice).notifications.unread
  end

  test "notifications require signing in" do
    get notifications_url
    assert_redirected_to new_session_url
  end
end
