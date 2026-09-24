module McpTools
  # The side channel, held to the same rule as everything else: a notification
  # about something the caller may no longer see is dropped rather than
  # described.
  class Notifications < Tool
    extend NotificationsHelper

    DEFAULT_LIMIT = 20
    MAX_LIMIT = 50

    tool_name "notifications"
    title "Your Kith notifications"
    description "New followers, accepted follows and replies to your posts, newest first."
    read_only "Your Kith notifications"
    input_schema(
      properties: {
        limit: { type: "integer", description: "How many to return.", minimum: 1, maximum: MAX_LIMIT },
        unread_only: { type: "boolean", description: "Only the ones you haven't read." }
      },
      required: []
    )

    def self.call(server_context:, limit: nil, unread_only: false)
      notifications = server_context.member.notifications
      notifications = notifications.unread if unread_only
      notifications = notifications.newest_first
        .includes(:actor, :subject)
        .limit(clamp(limit, default: DEFAULT_LIMIT, max: MAX_LIMIT))
        .select { |notification| server_context.visibility.notification?(notification) }

      return text(unread_only ? "Nothing unread." : "Nothing yet.") if notifications.empty?

      text notifications.map { |notification|
        "#{notification.unread? ? "• " : "  "}#{notification.actor} #{notification_sentence(notification)}"
      }.join("\n")
    end
  end
end
