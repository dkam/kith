require "test_helper"

class FeedControllerTest < ActionDispatch::IntegrationTest
  setup do
    # Materialise the fixture posts into everyone's feeds, as writing them
    # would have.
    Post.find_each { |post| FanOutJob.perform_now(post) }
  end

  test "the feed is your own posts and those of people you follow" do
    sign_in_as members(:alice)
    get root_url

    assert_response :success
    assert_select "##{dom_id(posts(:alice_followers))}"
    assert_select "##{dom_id(posts(:bob_followers))}"
    assert_select "##{dom_id(posts(:carol_followers))}"
    assert_select "##{dom_id(posts(:dave_followers))}", false
  end

  test "the feed is strictly chronological, newest first" do
    sign_in_as members(:alice)
    get root_url

    ids = css_select("article[id^='post_']").map { |node| node["id"] }
    assert_equal ids, ids.sort_by { |id| -Post.find(id.delete_prefix("post_")).published_at.to_i }
  end

  test "a feed item whose post you may no longer see is not rendered" do
    sign_in_as members(:bob)
    get root_url
    assert_select "##{dom_id(posts(:alice_followers))}"

    follows(:bob_follows_alice).reject!

    get root_url
    assert_select "##{dom_id(posts(:alice_followers))}", false
  end

  test "an empty feed says so" do
    sign_in_as members(:dave)
    FeedItem.where(member: members(:dave)).delete_all

    get root_url
    assert_select "p", /Nothing here yet/
  end

  test "unread posts are marked, read ones are not" do
    sign_in_as members(:alice)
    item = members(:alice).feed_items.first
    item.read!

    get root_url

    assert_select "##{dom_id(item)}[data-feed-item-url]", false
    assert_select "[data-feed-item-url]"
  end

  test "marking one as read" do
    sign_in_as members(:alice)
    item = members(:alice).feed_items.unread.first

    patch feed_item_url(item)

    assert_response :no_content
    assert item.reload.read?
  end

  test "you cannot mark someone else's feed item as read" do
    sign_in_as members(:alice)
    item = FeedItem.where(member: members(:bob)).first

    patch feed_item_url(item)

    assert_response :not_found
    refute item.reload.read?
  end

  test "marking everything as read" do
    sign_in_as members(:alice)
    assert members(:alice).feed_items.unread.exists?

    post read_all_feed_items_url

    assert_redirected_to root_url
    assert_empty members(:alice).feed_items.unread
  end

  test "the feed paginates with a lazy turbo frame" do
    sign_in_as members(:alice)
    25.times { |i| published_post(actors(:bob), body: "Filler #{i}") }
    Post.find_each { |post| FanOutJob.perform_now(post) }

    get root_url
    assert_select "turbo-frame[loading='lazy'][src*='before=']"

    cursor = members(:alice).feed_items.newest_first.offset(FeedController::PAGE_SIZE - 1).first.id
    get root_url(before: cursor), headers: { "Turbo-Frame" => "feed-page-#{cursor}" }

    assert_response :success
    assert_select "article[id^='post_']"
    assert_select "h1", false, "a turbo frame request should not re-render the page chrome"
  end

  test "the last page says so instead of asking for another" do
    sign_in_as members(:dave)
    follows(:dave_follows_alice).accept!
    FanOutJob.perform_now(follows(:dave_follows_alice))

    get root_url
    assert_select "p", /That's everything/
  end

  test "the feed requires signing in" do
    get root_url
    assert_redirected_to new_session_url
  end
end
