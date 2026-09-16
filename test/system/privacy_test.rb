require "application_system_test_case"

# The promises the product makes, exercised through a real browser rather than
# through the policy object that implements them.
class PrivacyTest < ApplicationSystemTestCase
  include ActiveJob::TestHelper

  setup { Post.find_each { |post| FanOutJob.perform_now(post) } }

  test "a followers-only post is not in a stranger's feed, and its permalink is a dead end" do
    sign_in_as members(:dave)

    refute_text "The long way round"

    visit post_path(posts(:alice_followers))
    assert_no_text "The long way round"
  end

  test "a public post is readable with no account at all" do
    visit post_path(posts(:alice_public))

    assert_text "On keeping a notebook"
    assert_no_text "Sign out"
  end

  test "an invisible member's reply is not shown to a stranger, and the count agrees" do
    sign_in_as members(:bob)
    visit post_path(posts(:alice_followers))

    assert_text "The coast road is always worth it."
    assert_no_text "Carol is invisible"

    shown = all("li[id^='comment_']").size
    assert_text(/#{shown} replies/i)
  end

  test "a name without a profile link is still a name" do
    sign_in_as members(:dave)
    visit post_path(posts(:alice_public))

    within("li", text: "A comment on a public post") do
      # Bob is discoverable by everyone, so his name links.
      assert_selector "a", text: "Bob Ndlovu"
    end

    posts(:alice_public).comments.create!(actor: actors(:alice), body: "A word from the author")
    visit post_path(posts(:alice_public))

    within("li", text: "A word from the author") do
      # Alice is connections-only and Dave is not connected to her.
      assert_text "Alice Brennan"
      assert_no_selector "a", text: "Alice Brennan"
    end
  end

  test "unfollowing takes the posts out of the feed" do
    sign_in_as members(:bob)
    assert_text "The long way round"

    visit profile_path("alice")
    within("##{dom_id(actors(:alice), :follow_button)}") do
      click_on "Following — unfollow"
      assert_button "Follow", exact: true, wait: 5
    end

    visit root_path
    assert_no_text "The long way round"
  end

  test "a photo on a private post is not served to someone outside the audience" do
    posts(:alice_followers).photos.attach(
      io: file_fixture("landscape.jpg").open, filename: "landscape.jpg", content_type: "image/jpeg")
    photo_path = media_path(AttachableMedia.signed_id(posts(:alice_followers).photos.first), :feed)

    sign_in_as members(:dave)
    visit photo_path

    assert_no_selector "img"
  end
end
