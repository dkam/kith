require "application_system_test_case"

class WritingTest < ApplicationSystemTestCase
  include ActiveJob::TestHelper

  setup { sign_in_as members(:alice) }

  test "writing a post with photos dropped into the words" do
    visit new_post_path

    fill_in "Title", with: "Two of them"
    compose "Dropped, not chosen."
    drop_photos file_fixture("landscape.jpg"), file_fixture("portrait.jpg")

    # The editor previews each photo through MediaController#pending — never
    # from an Active Storage blob URL, which would go on working for anyone
    # holding it long after the post had found its audience.
    assert_no_selector "lexxy-editor img[src*='/rails/active_storage/']"

    perform_enqueued_jobs { click_on "Post" }

    assert_text "Two of them"
    assert_text "Dropped, not chosen."
    assert_selector "article img[src^='/media/']", count: 2
    assert_no_selector "img[src*='/rails/active_storage/']"

    # And nothing about the file's own address survives into the post.
    refute_includes page.html, "/rails/active_storage/"
  end

  test "a photo comes back through MediaController when the post is edited" do
    visit new_post_path
    compose "One photo."
    drop_photos file_fixture("landscape.jpg")

    perform_enqueued_jobs { click_on "Post" }

    assert_text "One photo."
    assert_selector "article img[src^='/media/']"

    click_on "Edit"

    assert_selector "lexxy-editor img[src^='/media/']", wait: 10
    assert_no_selector "lexxy-editor img[src*='/rails/active_storage/']"
  end

  test "markdown shortcuts still work, they just aren't what is stored" do
    visit new_post_path
    compose "**bold** and _italic_.\n- one\ntwo"
    click_on "Post"

    assert_selector "article strong", text: "bold"
    assert_selector "article em", text: "italic"
    assert_selector "article li", count: 2
  end

  test "the audience is offered once and stated thereafter" do
    visit new_post_path
    assert_selector "input[type=radio][name='post[audience]']", count: 2, visible: :all

    choose "Anyone with the link"
    compose "Out in the open."
    click_on "Post"

    assert_selector "span", text: /public/i

    click_on "Edit"
    assert_no_selector "input[type=radio][name='post[audience]']", visible: :all
    assert_text "readable by anyone with the link"
    assert_text "can't be changed"
  end

  test "deleting a post" do
    visit post_path(posts(:alice_followers))

    within("article") do
      accept_confirm { click_on "Delete" }
    end

    assert_text "Deleted."
    assert_no_text "The long way round"
  end
end
