require "test_helper"

class NotificationTest < ActiveSupport::TestCase
  test "delivering to a local actor tells their member" do
    notification = Notification.deliver(:new_follower, to: actors(:alice), from: actors(:carol), about: follows(:carol_follows_dave))

    assert_equal members(:alice), notification.member
    assert_equal actors(:carol), notification.actor
    assert notification.new_follower?
    refute notification.read?
  end

  test "nobody is notified about their own doing" do
    assert_nil Notification.deliver(:new_comment, to: actors(:alice), from: actors(:alice), about: comments(:alice_on_alice_followers))
  end

  test "an actor with no member here gets nothing" do
    remote = RemoteActor.create!(handle: "zoe", domain: "example.social", inbox_url: "https://example.social/inbox")

    assert_nil Notification.deliver(:new_follower, to: remote, from: actors(:alice), about: follows(:alice_follows_bob))
  end

  test "the same event does not ring the bell twice" do
    assert_difference -> { Notification.count }, 1 do
      2.times { Notification.deliver(:new_follower, to: actors(:alice), from: actors(:dave), about: follows(:dave_follows_alice)) }
    end
  end

  test "the same subject can carry two different kinds" do
    follow = follows(:dave_follows_alice)

    assert_difference -> { Notification.count }, 2 do
      Notification.deliver(:new_follower, to: actors(:alice), from: actors(:dave), about: follow)
      Notification.deliver(:follow_accepted, to: actors(:dave), from: actors(:alice), about: follow)
    end
  end

  test "marking read is idempotent" do
    notification = Notification.deliver(:new_follower, to: actors(:alice), from: actors(:dave), about: follows(:dave_follows_alice))

    notification.read!
    first = notification.reload.read_at
    notification.read!

    assert_equal first, notification.reload.read_at
  end

  test "replying to a post notifies its author" do
    assert_difference -> { members(:alice).notifications.count }, 1 do
      posts(:alice_followers).comments.create!(actor: actors(:bob), body: "Nice")
    end

    assert members(:alice).notifications.order(:id).last.new_comment?
  end

  test "replying to your own post notifies nobody" do
    assert_no_difference -> { Notification.count } do
      posts(:alice_followers).comments.create!(actor: actors(:alice), body: "To myself")
    end
  end

  test "deleting the subject deletes the notification" do
    comment = posts(:alice_followers).comments.create!(actor: actors(:bob), body: "Briefly")
    assert_equal 1, Notification.where(subject: comment).count

    comment.destroy

    assert_equal 0, Notification.where(subject_type: "Comment", subject_id: comment.id).count
  end

  test "deleting a member deletes their notifications" do
    posts(:alice_followers).comments.create!(actor: actors(:bob), body: "Hello")

    assert_difference -> { Notification.count }, -1 do
      members(:alice).destroy
    end
  end
end
