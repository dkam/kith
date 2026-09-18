# The MCP server Kith presents to one member's agent.
#
# It is built per request and thrown away: the token is the whole of the
# session, and nothing is remembered between calls. The token is handed to the
# SDK as the server context, which is how a tool gets a Visibility without ever
# seeing a request.
class McpServer
  NAME = "kith"
  # The MCP server's own version, not the app's. It moves when the tools do.
  VERSION = "1.1.0"

  READING = [ McpTools::Whoami, McpTools::Feed, McpTools::ReadPost, McpTools::Notifications ].freeze
  WRITING = [ McpTools::WritePost, McpTools::WriteComment, McpTools::MarkRead ].freeze

  INSTRUCTIONS = <<~TEXT
    Kith is a small private network — a few dozen friends, no public timeline,
    no reposting and no likes. These tools give one member's own view of it and
    nothing else. Everything is answered under that member's own permissions,
    so a post you cannot find is a post they cannot see.

    Start with `whoami`, then `feed` for what is waiting, then `post` for the
    ids it gives you.
  TEXT

  WRITING_INSTRUCTIONS = <<~TEXT

    This endpoint may also write. Anything it writes is published as the member,
    under their name, to people who know them — so write what they asked for and
    nothing else. A post's audience is fixed the moment it is written and can
    never be changed, and `public` means anyone on the internet, with other
    servers free to keep copies. When in doubt, leave it at followers.
  TEXT

  def self.for(token)
    MCP::Server.new(
      name: NAME,
      title: "Kith",
      version: VERSION,
      instructions: instructions_for(token),
      tools: tools_for(token),
      server_context: token
    )
  end

  # What a token may do is decided once, here, from the grant it was issued
  # with. A read-only endpoint is not offered the writing tools and then
  # refused them — it is never told they exist.
  def self.tools_for(token)
    token.writes? ? READING + WRITING : READING
  end

  def self.instructions_for(token)
    token.writes? ? INSTRUCTIONS + WRITING_INSTRUCTIONS : INSTRUCTIONS
  end
end
