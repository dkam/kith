module McpTools
  # Clearing the unread marker, so an agent that has read the feed aloud can
  # leave it the way a person who had read it would.
  #
  # It works on the reader's own feed item, which is where unread state lives —
  # one member's reading never touches anyone else's.
  class MarkRead < Tool
    tool_name "mark_read"
    title "Mark a Kith post as read"
    description "Clear the unread marker on one post in your feed, or on everything in it."
    annotations(read_only_hint: false, destructive_hint: false, idempotent_hint: true, open_world_hint: false,
      title: "Mark a Kith post as read")
    input_schema(
      properties: {
        post_id: { type: "integer", description: "The post to mark. Leave it out and pass all: true to clear the lot." },
        all: { type: "boolean", description: "Mark everything unread as read." }
      },
      required: []
    )

    def self.call(server_context:, post_id: nil, all: false)
      return mark_everything(server_context.member) if all
      return not_found("post") if post_id.nil?

      item = server_context.member.feed_items.find_by(post_id: post_id)
      return not_found("post") if item.nil?

      item.read!
      text "Marked as read."
    end

    def self.mark_everything(member)
      cleared = member.feed_items.unread.update_all(read_at: Time.current, updated_at: Time.current)

      text "Marked #{cleared} as read."
    end

    private_class_method :mark_everything
  end
end
