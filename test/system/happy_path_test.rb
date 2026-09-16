require "application_system_test_case"

# The whole arc, in one pass: someone is invited, joins, writes, is followed,
# accepts, and gets a reply. If this breaks, the product is broken, whatever
# the unit tests say.
class HappyPathTest < ApplicationSystemTestCase
  include ActiveJob::TestHelper

  test "invite, join, write, follow, accept, reply" do
    perform_enqueued_jobs do
      invite_url = alice_issues_an_invite
      zoe_joins_with(invite_url)
      zoe_writes_a_post
      zoe_asks_to_follow_alice
      alice_accepts_and_writes
      zoe_reads_and_replies
      alice_sees_the_reply
    end
  end

  private
    def alice_issues_an_invite
      sign_in_through_the_form members(:alice), password: "password123"

      click_on "Invites"
      assert_text "Each link works once"

      click_on "Create an invite"
      assert_text "Invite ready"

      code = Invite.order(:created_at).last.code
      sign_out

      join_path(code)
    end

    def zoe_joins_with(path)
      visit path
      assert_text "Alice Brennan invited you"

      fill_in "Handle", with: "zoe"
      fill_in "Name", with: "Zoe Adeyemi"
      fill_in "Email", with: "zoe@example.com"
      fill_in "Password", with: "correcthorse"
      fill_in "Confirm password", with: "correcthorse"
      click_on "Join"

      assert_text "Welcome to Kith"
      assert_text "You are @zoe"

      zoe = Member.find_by!(email_address: "zoe@example.com")
      assert_equal members(:alice), zoe.inviter_member, "the invite records who issued it"
      refute Invite.order(:created_at).last.open?, "and is spent"
    end

    def zoe_writes_a_post
      click_on "Write"

      fill_in "Title", with: "First light"
      fill_in "Words", with: "The **kettle** is on."
      choose "People who follow me"
      click_on "Post"

      assert_text "First light"
      assert_selector "strong", text: "kettle"
    end

    def zoe_asks_to_follow_alice
      visit profile_path("alice")
      assert_text "Alice Brennan"

      click_on "Follow"
      assert_text "Asked", wait: 5

      assert Follow.between(Actor.find_by(handle: "zoe"), actors(:alice)).first.requested?
      sign_out
    end

    def alice_accepts_and_writes
      sign_in_as members(:alice)

      click_on "Notifications"
      assert_text "Zoe Adeyemi asked to follow you"

      click_on "Following"
      # Dave is waiting too, from the fixtures.
      assert_text "2 people are waiting"

      within("li", text: "Zoe Adeyemi asked to follow you") do
        click_on "Accept"
      end

      assert_text "Zoe Adeyemi follows you now", wait: 5
      assert_text "1 person is waiting", wait: 5

      click_on "Write"
      fill_in "Title", with: "The long road"
      fill_in "Words", with: "Four hours longer, and worth it."
      click_on "Post"
      assert_text "The long road"

      sign_out
    end

    def zoe_reads_and_replies
      sign_in_through_the_form Member.find_by!(email_address: "zoe@example.com"), password: "correcthorse"

      assert_text "The long road", wait: 5
      click_on "The long road"
      assert_selector "h1", text: "The long road"

      fill_in "Your reply", with: "Worth it every time."
      click_on "Reply"

      assert_text "Worth it every time.", wait: 5
      assert_text "1 reply"

      sign_out
    end

    def alice_sees_the_reply
      sign_in_as members(:alice)

      click_on "Notifications"
      assert_text "Zoe Adeyemi replied to"

      click_on "Zoe Adeyemi replied to"
      assert_text "Worth it every time."
    end
end
