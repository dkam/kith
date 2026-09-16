require "application_system_test_case"

class WritingTest < ApplicationSystemTestCase
  include ActiveJob::TestHelper

  setup { sign_in_as members(:alice) }

  test "writing a post with photos, dropped onto the form" do
    visit new_post_path

    fill_in "Title", with: "Two of them"
    fill_in "Words", with: "Dropped, not chosen."

    # Capybara's attach_file drives the same input the drop handler assigns to;
    # the Stimulus controller's preview runs off the input's change event either
    # way.
    attach_file "post[photos][]", [ file_fixture("landscape.jpg"), file_fixture("portrait.jpg") ], make_visible: true

    assert_text "2 photos ready", wait: 5

    perform_enqueued_jobs { click_on "Post" }

    assert_text "Two of them"
    assert_selector "img[src^='/media/']", count: 2
    assert_no_selector "img[src*='/rails/active_storage/']"
  end

  test "the audience is offered once and stated thereafter" do
    visit new_post_path
    assert_selector "input[type=radio][name='post[audience]']", count: 2, visible: :all

    choose "Anyone with the link"
    fill_in "Words", with: "Out in the open."
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
