require "test_helper"

class FanOutJobTest < ActiveJob::TestCase
  test "a new post reaches its author and their accepted followers" do
    post = published_post(actors(:alice), body: "Fanned out")

    perform_enqueued_jobs

    assert_readers [ members(:alice), members(:bob) ], post
  end

  test "a pending follower is not a reader" do
    post = published_post(actors(:alice), body: "Not for Dave")
    perform_enqueued_jobs

    refute FeedItem.exists?(member: members(:dave), post: post)
  end

  test "a public post still only fans out to followers" do
    post = published_post(actors(:alice), body: "Public but not broadcast", audience: :public)
    perform_enqueued_jobs

    assert_readers [ members(:alice), members(:bob) ], post
  end

  # --- Drafts ---------------------------------------------------------------

  test "a draft reaches nobody, not even its author's own feed" do
    post = actors(:alice).posts.create!(body: "Not yet")

    perform_enqueued_jobs

    assert_empty FeedItem.where(post: post)
  end

  test "publishing is what fans a draft out" do
    post = actors(:alice).posts.create!(body: "Later, then")

    assert_enqueued_with(job: FanOutJob) { post.publish! }
    perform_enqueued_jobs

    assert_readers [ members(:alice), members(:bob) ], post
  end

  # Belt and braces: the job is the one thing that writes into other people's
  # feeds, so it refuses a draft even when handed one directly.
  test "the job refuses a draft handed straight to it" do
    post = actors(:alice).posts.create!(body: "Direct")

    FanOutJob.perform_now(post)

    assert_empty FeedItem.where(post: post)
  end

  test "editing a draft does not fan it out over and over" do
    post = actors(:alice).posts.create!(body: "A first go")

    assert_no_enqueued_jobs(only: FanOutJob) { post.update!(body: "A second go") }
  end

  test "editing a published post does not fan it out again" do
    post = published_post(actors(:alice), body: "Said once")

    assert_no_enqueued_jobs(only: FanOutJob) { post.update!(title: "Typo fixed") }
  end

  test "writing a post enqueues the fan-out" do
    assert_enqueued_with job: FanOutJob do
      published_post(actors(:alice), body: "Hello")
    end
  end

  test "fanning out twice does not duplicate the item" do
    post = published_post(actors(:alice), body: "Once")
    perform_enqueued_jobs

    assert_no_difference -> { FeedItem.count } do
      FanOutJob.perform_now(post)
    end
  end

  test "accepting a follow back-fills what the follower can now see" do
    assert_empty members(:dave).feed_items

    follows(:dave_follows_alice).accept!
    FanOutJob.perform_now(follows(:dave_follows_alice))

    assert_equal [ posts(:alice_followers), posts(:alice_public) ].map(&:id).sort,
                 members(:dave).feed_items.map(&:post_id).sort
  end

  test "back-filling never hands over a post the policy would refuse" do
    follows(:dave_follows_alice).accept!
    FanOutJob.perform_now(follows(:dave_follows_alice))

    policy = Visibility.new(actors(:dave).reload)
    members(:dave).feed_items.each do |item|
      assert policy.post?(item.post), "back-fill handed Dave a post Visibility refuses"
    end
  end

  test "a follow that has not been accepted back-fills nothing" do
    FanOutJob.perform_now(follows(:dave_follows_alice))

    assert_empty members(:dave).feed_items
  end

  test "deleting a post deletes it from every feed" do
    post = published_post(actors(:alice), body: "Briefly")
    perform_enqueued_jobs
    assert FeedItem.exists?(post: post)

    post.destroy

    refute FeedItem.exists?(post_id: post.id)
  end

  private
    def assert_readers(members, post)
      assert_equal members.map(&:id).sort, FeedItem.where(post: post).pluck(:member_id).sort
    end
end
