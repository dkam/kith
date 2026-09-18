require "test_helper"

class McpTokenTest < ActiveSupport::TestCase
  test "a new token gets a random value" do
    token = McpToken.create!(member: members(:carol))

    assert_equal McpToken::TOKEN_LENGTH, token.token.length
    assert_not_equal mcp_tokens(:alice).token, token.token
  end

  test "authenticate finds the member behind a token" do
    assert_equal members(:alice), McpToken.authenticate(mcp_tokens(:alice).token).member
  end

  test "authenticate refuses a blank or unknown token" do
    assert_nil McpToken.authenticate(nil)
    assert_nil McpToken.authenticate("")
    assert_nil McpToken.authenticate("nosuchtokenatall00000000")
  end

  test "rotating replaces the value and forgets when it was last used" do
    token = mcp_tokens(:alice)
    was = token.token
    token.update_column(:last_used_at, Time.current)

    token.rotate!

    assert_not_equal was, token.token
    assert_nil token.last_used_at
    assert_nil McpToken.authenticate(was)
  end

  test "a token sees exactly what its member sees" do
    assert_equal actors(:alice), mcp_tokens(:alice).visibility.viewer
  end

  test "phase one tokens only read" do
    assert_predicate mcp_tokens(:alice), :access_read_only?
  end

  test "a member has one token, made when they first ask" do
    member = members(:carol)

    assert_nil member.mcp_token
    token = member.mcp_token!

    assert_equal token, member.reload.mcp_token!
  end

  test "deleting a member takes their token with them" do
    token = mcp_tokens(:alice).token
    members(:alice).destroy

    assert_not McpToken.exists?(token: token)
  end
end
