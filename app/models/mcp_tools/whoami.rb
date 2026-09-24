module McpTools
  # Who the token belongs to. The first thing an agent should ask, and the only
  # tool that answers about the caller rather than about what they can see.
  class Whoami < Tool
    tool_name "whoami"
    title "Who you are on Kith"
    description "The Kith member this endpoint belongs to: handle, name, discoverability, and how much is waiting to be read."
    read_only "Who you are on Kith"
    input_schema(properties: {}, required: [])

    def self.call(server_context:)
      member = server_context.member
      actor = member.actor

      text <<~REPORT
        @#{actor.handle} — #{actor.display_name}
        Discoverable by: #{actor.discoverability}
        Following: #{actor.followees.count} · Followers: #{actor.followers.count}
        Unread in your feed: #{unread_count(member, server_context.visibility)}
        This endpoint: #{server_context.name} — #{server_context.access_label}
      REPORT
    end

    # Derived from the visible set, never from the table: an unread count is a
    # disclosure like any other.
    def self.unread_count(member, visibility)
      member.feed_items.unread.includes(:post).count { |item| visibility.post?(item.post) }
    end
    private_class_method :unread_count
  end
end
