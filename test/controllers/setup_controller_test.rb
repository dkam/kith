require "test_helper"

class SetupControllerTest < ActionDispatch::IntegrationTest
  test "setup is not there once anybody has joined" do
    get setup_url
    assert_response :not_found

    assert_no_difference -> { Member.count } do
      post setup_url, params: setup_params
    end
    assert_response :not_found
  end

  # 404, not 403: the status is the same as for a route that never existed, so
  # a stranger can't learn whether this instance has anybody in it.
  test "a closed setup looks exactly like a page that isn't there" do
    get setup_url
    closed = response.status

    get "/no-such-page-at-all"

    assert_equal response.status, closed
  end

  test "an empty instance offers setup" do
    empty_the_instance

    get setup_url

    assert_response :success
    assert_select "h1", "Set up Kith"
    assert_no_match Setup.code, response.body, "the code is shown on the console, never on the page"
  end

  test "the sign in page points at setup while the instance is empty" do
    get new_session_url
    assert_select "a[href=?]", setup_path, count: 0

    empty_the_instance
    get new_session_url

    assert_select "a[href=?]", setup_path, text: "Set up Kith"
  end

  test "the right code founds the instance and signs the first member in" do
    empty_the_instance

    assert_difference -> { Member.count }, 1 do
      post setup_url, params: setup_params
    end

    assert_redirected_to settings_url

    member = Member.sole
    assert_nil member.inviter_member, "the first member has nobody above them"
    assert_equal "dan", member.handle
    assert_equal "Dan", member.display_name
    assert member.actor.everyone?, "the only member has nobody to hide from yet"

    # Signed in, and not asked to do it again.
    get root_url
    assert_response :success
  end

  test "setup closes behind the first member" do
    empty_the_instance
    post setup_url, params: setup_params

    get setup_url

    assert_response :not_found
  end

  test "a wrong code creates nobody and says so" do
    empty_the_instance

    assert_no_difference -> { Member.count } do
      post setup_url, params: setup_params(code: "ZZZZ-ZZZZ-ZZZZ")
    end

    assert_response :unprocessable_content
    assert_select ".alert", /doesn't match the one on the server's console/
  end

  test "a wrong code hands back everything but the passwords" do
    empty_the_instance

    post setup_url, params: setup_params(code: "ZZZZ-ZZZZ-ZZZZ")

    assert_select "input[name=?][value=?]", "member[email_address]", "dan@example.com"
    assert_select "input[name=?][value=?]", "member[actor_attributes][handle]", "dan"
    assert_select "input[name=?]:not([value])", "member[password]"
  end

  test "the right code with a bad member creates nobody" do
    empty_the_instance

    assert_no_difference -> { Member.count } do
      post setup_url, params: setup_params(member: { email_address: "not-an-email", password: "short", password_confirmation: "short", actor_attributes: { handle: "dan" } })
    end

    assert_response :unprocessable_content
  end

  test "a post with nothing in it but the right code creates nobody" do
    empty_the_instance

    assert_no_difference -> { Member.count } do
      post setup_url, params: { code: Setup.code }
    end

    assert_response :unprocessable_content
  end

  private
    def empty_the_instance
      Member.destroy_all
    end

    def setup_params(code: Setup.code, member: nil)
      {
        code: code,
        member: member || {
          email_address: "dan@example.com",
          password: "a good long password",
          password_confirmation: "a good long password",
          actor_attributes: { handle: "dan", display_name: "Dan" }
        }
      }
    end
end
