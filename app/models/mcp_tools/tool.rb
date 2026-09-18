module McpTools
  # What every Kith tool shares: a read of the caller's world, rendered as the
  # prose an agent is going to read anyway.
  #
  # The caller arrives as `server_context` — an McpToken, forwarded by the MCP
  # SDK — so a tool never sees a request, a session or a cookie. It sees a
  # Visibility, and it asks.
  class Tool < MCP::Tool
    class << self
      private
        def text(body)
          MCP::Tool::Response.new([ { type: "text", text: body.to_s } ])
        end

        # The one refusal shape. As in the rest of Kith, a thing the caller may
        # not see and a thing that isn't there give the same answer, because
        # telling them apart is the disclosure.
        def not_found(what)
          MCP::Tool::Response.new([ { type: "text", text: "No such #{what}." } ], error: true)
        end

        def read_only(title)
          annotations(read_only_hint: true, destructive_hint: false, idempotent_hint: true, open_world_hint: false, title: title)
        end

        # A post, one line, with the id the other tools take.
        def post_line(post)
          [
            "##{post.id}",
            "@#{post.handle}",
            post.published_at.to_fs(:long),
            post.audience,
            post.excerpt(length: 100)
          ].join(" · ")
        end

        def clamp(limit, default:, max:)
          return default if limit.nil?

          limit.to_i.clamp(1, max)
        end
    end
  end
end
