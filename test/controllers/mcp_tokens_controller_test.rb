require "test_helper"

class McpTokensControllerTest < ActionDispatch::IntegrationTest
  test "the settings page lists your endpoints, and nobody else's" do
    sign_in_as members(:alice)
    get settings_url

    assert_response :success
    assert_select "input[value=?]", mcp_url(token: mcp_tokens(:alice_reader).token)
    assert_select "input[value=?]", mcp_url(token: mcp_tokens(:alice_writer).token)
    assert_select "input[value=?]", mcp_url(token: mcp_tokens(:bob).token), false
  end

  test "a member with no endpoints is told so rather than issued one" do
    sign_in_as members(:carol)

    assert_no_difference -> { McpToken.count } do
      get settings_url
    end

    assert_select "p", text: /You haven't made one yet/
  end

  test "making an endpoint names it and fixes what it may do" do
    sign_in_as members(:carol)

    assert_difference -> { McpToken.count }, 1 do
      post settings_mcp_tokens_url, params: { mcp_token: { name: "Carol's phone", access: "read_write" } }
    end

    token = members(:carol).mcp_tokens.sole
    assert_equal "Carol's phone", token.name
    assert_predicate token, :writes?
    assert_redirected_to settings_url
  end

  test "an endpoint with no name is refused" do
    sign_in_as members(:carol)

    assert_no_difference -> { McpToken.count } do
      post settings_mcp_tokens_url, params: { mcp_token: { name: "", access: "read_only" } }
    end
  end

  test "resetting issues a new value and kills the old one" do
    was = mcp_tokens(:alice_reader).token
    sign_in_as members(:alice)

    patch settings_mcp_token_url(mcp_tokens(:alice_reader))

    assert_redirected_to settings_url
    assert_not_equal was, mcp_tokens(:alice_reader).reload.token
    assert_nil McpToken.authenticate(was)
  end

  test "revoking removes it" do
    was = mcp_tokens(:alice_reader).token
    sign_in_as members(:alice)

    assert_difference -> { McpToken.count }, -1 do
      delete settings_mcp_token_url(mcp_tokens(:alice_reader))
    end

    assert_nil McpToken.authenticate(was)
  end

  test "somebody else's endpoint is not yours to reset or revoke" do
    sign_in_as members(:alice)

    patch settings_mcp_token_url(mcp_tokens(:bob))
    assert_response :not_found

    delete settings_mcp_token_url(mcp_tokens(:bob))
    assert_response :not_found

    assert_equal "bobsmcptokenvalue00000003", mcp_tokens(:bob).reload.token
  end

  test "all of it needs a session of your own" do
    post settings_mcp_tokens_url, params: { mcp_token: { name: "Nobody's", access: "read_only" } }
    assert_redirected_to new_session_url

    patch settings_mcp_token_url(mcp_tokens(:alice_reader))
    assert_redirected_to new_session_url

    delete settings_mcp_token_url(mcp_tokens(:alice_reader))
    assert_redirected_to new_session_url

    assert_equal "alicesmcptokenvalue00001", mcp_tokens(:alice_reader).reload.token
  end
end
