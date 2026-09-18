# The MCP server Kith presents to one member's agent.
#
# It is built per request and thrown away: the token is the whole of the
# session, and nothing is remembered between calls. The token is handed to the
# SDK as the server context, which is how a tool gets a Visibility without ever
# seeing a request.
class McpServer
  NAME = "kith"
  # The MCP server's own version, not the app's. It moves when the tools do.
  VERSION = "1.0.0"
  TOOLS = [ McpTools::Whoami, McpTools::Feed, McpTools::ReadPost, McpTools::Notifications ].freeze

  INSTRUCTIONS = <<~TEXT
    Kith is a small private network. These tools read one member's own view of
    it — their feed, a post they can open, their notifications — and nothing
    else. Everything is answered under that member's own permissions, so a post
    you cannot find is a post they cannot see.

    Start with `whoami`, then `feed` for what is waiting, then `post` for the
    ids it gives you.
  TEXT

  def self.for(token)
    MCP::Server.new(
      name: NAME,
      title: "Kith",
      version: VERSION,
      instructions: INSTRUCTIONS,
      tools: TOOLS,
      server_context: token
    )
  end
end
