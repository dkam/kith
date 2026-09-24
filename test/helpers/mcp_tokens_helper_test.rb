require "test_helper"

class McpTokensHelperTest < ActionView::TestCase
  include McpTokensHelper

  test "the server name a client config uses is the member's own name for it" do
    assert_equal "kith-alice-s-laptop", mcp_server_name(mcp_tokens(:alice_reader))
  end

  test "a name with nothing typeable in it still gives a usable server name" do
    assert_equal "kith", mcp_server_name(McpToken.new(name: "—"))
  end

  test "the opencode snippet is the shape opencode.json wants" do
    config = JSON.parse(opencode_mcp_config(mcp_tokens(:alice_reader)))
    entry = config.fetch("mcp").fetch("kith-alice-s-laptop")

    assert_equal "remote", entry["type"]
    assert_equal true, entry["enabled"]
    assert_includes entry["url"], mcp_tokens(:alice_reader).token
  end
end
