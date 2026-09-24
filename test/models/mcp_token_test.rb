require "test_helper"

class McpTokenTest < ActiveSupport::TestCase
  test "a new token gets a random value" do
    token = McpToken.create!(member: members(:carol), name: "Carol's laptop")

    assert_equal McpToken::TOKEN_LENGTH, token.token.length
    assert_not_equal mcp_tokens(:alice_reader).token, token.token
  end

  test "authenticate finds the member behind a token" do
    assert_equal members(:alice), McpToken.authenticate(mcp_tokens(:alice_reader).token).member
  end

  test "authenticate refuses a blank or unknown token" do
    assert_nil McpToken.authenticate(nil)
    assert_nil McpToken.authenticate("")
    assert_nil McpToken.authenticate("nosuchtokenatall00000000")
  end

  test "rotating replaces the value and forgets when it was last used" do
    token = mcp_tokens(:alice_reader)
    was = token.token
    token.update_column(:last_used_at, Time.current)

    token.rotate!

    assert_not_equal was, token.token
    assert_nil token.last_used_at
    assert_nil McpToken.authenticate(was)
  end

  test "a token sees exactly what its member sees" do
    assert_equal actors(:alice), mcp_tokens(:alice_reader).visibility.viewer
  end

  test "phase one tokens only read" do
    assert_predicate mcp_tokens(:alice_reader), :access_read_only?
  end

  test "an endpoint needs a name to be told apart from the others" do
    token = McpToken.new(member: members(:carol))

    assert_not token.valid?
    assert_includes token.errors.full_messages.to_sentence, "Name"
  end

  test "a member may hold several endpoints" do
    assert_equal [ "Alice's laptop", "Alice's desktop" ], members(:alice).mcp_tokens.oldest_first.map(&:name)
  end

  test "what an endpoint may do is fixed when it is made" do
    token = mcp_tokens(:alice_reader)
    token.access = :read_write

    assert_not token.valid?
    assert_equal "read only", token.reload.access_label
  end

  test "only a read and write endpoint writes" do
    assert_not_predicate mcp_tokens(:alice_reader), :writes?
    assert_predicate mcp_tokens(:alice_writer), :writes?
  end

  test "deleting a member takes their endpoints with them" do
    tokens = members(:alice).mcp_tokens.map(&:token)
    members(:alice).destroy

    assert_empty McpToken.where(token: tokens)
  end
end
