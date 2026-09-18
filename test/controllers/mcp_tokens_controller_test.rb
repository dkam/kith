require "test_helper"

class McpTokensControllerTest < ActionDispatch::IntegrationTest
  test "the settings page shows your endpoint, and nobody else's" do
    sign_in_as members(:alice)
    get settings_url

    assert_response :success
    assert_select "input[value=?]", mcp_url(token: mcp_tokens(:alice).token)
    assert_select "input[value=?]", mcp_url(token: mcp_tokens(:bob).token), false
  end

  test "a member who has never looked gets an endpoint when they do" do
    sign_in_as members(:carol)

    assert_difference -> { McpToken.count }, 1 do
      get settings_url
    end

    assert_select "input[value=?]", mcp_url(token: members(:carol).reload.mcp_token.token)
  end

  test "resetting issues a new endpoint and kills the old one" do
    was = mcp_tokens(:alice).token
    sign_in_as members(:alice)

    patch settings_mcp_token_url

    assert_redirected_to settings_url
    assert_not_equal was, members(:alice).reload.mcp_token.token
    assert_nil McpToken.authenticate(was)
  end

  test "resetting needs a session of your own" do
    patch settings_mcp_token_url

    assert_redirected_to new_session_url
    assert_equal mcp_tokens(:alice).token, members(:alice).reload.mcp_token.token
  end
end
