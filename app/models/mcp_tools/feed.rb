module McpTools
  # The reader, as an agent sees it. Strictly chronological, exactly as the
  # feed page is, and filtered through the same Visibility for the same reason:
  # a follow can be withdrawn after the fan-out.
  class Feed < Tool
    DEFAULT_LIMIT = 20
    MAX_LIMIT = 50

    tool_name "feed"
    title "Your Kith feed"
    description "Posts from the people you follow, and your own, newest first. Unread posts are marked with a bullet. Each line starts with the post id that the `post` tool takes."
    read_only "Your Kith feed"
    input_schema(
      properties: {
        limit: { type: "integer", description: "How many posts to return.", minimum: 1, maximum: MAX_LIMIT },
        unread_only: { type: "boolean", description: "Only posts you haven't read yet." }
      },
      required: []
    )

    def self.call(server_context:, limit: nil, unread_only: false)
      items = server_context.member.feed_items
      items = items.unread if unread_only
      items = items.newest_first.includes(post: :actor).limit(clamp(limit, default: DEFAULT_LIMIT, max: MAX_LIMIT)).to_a
      items.select! { |item| server_context.visibility.post?(item.post) }

      return text(unread_only ? "Nothing unread." : "Nothing to read.") if items.empty?

      text items.map { |item| "#{item.read? ? "  " : "• "}#{post_line(item.post)}" }.join("\n")
    end
  end
end
