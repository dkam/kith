module McpTokensHelper
  # What the endpoint is called in a client's config. A member's own name for
  # it, made safe to type: "Reading on the train" becomes kith-reading-on-the-train.
  def mcp_server_name(mcp_token)
    [ McpServer::NAME, mcp_token.name.parameterize.presence ].compact.join("-")
  end

  # opencode reads its MCP servers from opencode.json. The shape is its own
  # schema's: a named entry, type "remote", and the URL.
  def opencode_mcp_config(mcp_token)
    JSON.pretty_generate(
      "mcp" => {
        mcp_server_name(mcp_token) => {
          "type" => "remote",
          "url" => mcp_url(token: mcp_token.token),
          "enabled" => true
        }
      }
    )
  end
end
