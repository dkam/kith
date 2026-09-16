require "test_helper"

class FeedItemTest < ActiveSupport::TestCase
  setup { Post.find_each { |post| FanOutJob.perform_now(post) } }

  test "items start unread" do
    refute members(:alice).feed_items.first.read?
  end

  test "marking read is idempotent" do
    item = members(:alice).feed_items.first
    item.read!
    first_read = item.reload.read_at

    item.read!
    assert_equal first_read, item.reload.read_at
  end

  test "the feed reads newest first by when the post was written" do
    items = members(:alice).feed_items.newest_first.to_a

    assert_equal items.map { |item| item.post.published_at }.sort.reverse,
                 items.map { |item| item.post.published_at }
  end

  test "a back-filled old post lands in its right place, not at the top" do
    follows(:dave_follows_alice).accept!
    FanOutJob.perform_now(follows(:dave_follows_alice))

    newest = members(:dave).feed_items.newest_first.first
    assert_equal posts(:dave_followers), newest.post,
      "Dave's own, newer post should still be top of his feed after a back-fill"
  end

  test "the keyset cursor pages without skipping or repeating" do
    member = members(:alice)
    all = member.feed_items.newest_first.to_a
    assert_operator all.size, :>=, 3

    first_page = member.feed_items.newest_first.limit(2).to_a
    second_page = member.feed_items.before(first_page.last.id).newest_first.to_a

    assert_equal all, first_page + second_page
  end

  test "a cursor that no longer exists pages from the start rather than failing" do
    member = members(:alice)

    assert_equal member.feed_items.newest_first.to_a, member.feed_items.before(999_999).newest_first.to_a
  end

  test "one reader's unread state is their own" do
    shared = FeedItem.where(post: posts(:alice_followers))
    assert_equal 2, shared.count

    members(:alice).feed_items.find_by(post: posts(:alice_followers)).read!

    refute FeedItem.find_by(member: members(:bob), post: posts(:alice_followers)).read?
  end

  test "deleting a member deletes their feed, and nobody else's" do
    before = FeedItem.where(member: members(:bob)).count
    assert_operator before, :>, 0

    members(:alice).destroy

    assert_equal before, FeedItem.where(member: members(:bob)).count
  end
end
