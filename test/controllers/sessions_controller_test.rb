require "test_helper"

class SessionsControllerTest < ActionDispatch::IntegrationTest
  test "signing in" do
    post session_url, params: { email_address: "alice@example.com", password: "password123" }
    assert_redirected_to root_url

    get root_url
    assert_response :success
  end

  test "signing in with a bad password" do
    post session_url, params: { email_address: "alice@example.com", password: "wrong" }
    assert_redirected_to new_session_url
    assert_equal "Try another email address or password.", flash[:alert]
  end

  test "signing out" do
    sign_in_as members(:alice)

    delete session_url
    assert_redirected_to new_session_url

    get root_url
    assert_redirected_to new_session_url
  end

  test "an unauthenticated visitor is sent to sign in and back again" do
    get root_url
    assert_redirected_to new_session_url

    post session_url, params: { email_address: "alice@example.com", password: "password123" }
    assert_redirected_to root_url
  end
end
