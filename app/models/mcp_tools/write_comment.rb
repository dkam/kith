module McpTools
  # A flat reply, on a post the caller can see.
  #
  # The post is found through Visibility's scope, so an agent cannot comment
  # its way into discovering that a post it may not read exists: an unreadable
  # post and an absent one refuse identically.
  class WriteComment < Tool
    tool_name "comment"
    title "Comment on a Kith post"
    description "Reply to a post, as this member. Comments are flat and plain text — there is no threading, and the post's readers are who sees it."
    annotations(read_only_hint: false, destructive_hint: false, idempotent_hint: false, open_world_hint: false,
      title: "Comment on a Kith post")
    input_schema(
      properties: {
        post_id: { type: "integer", description: "The post's id, as `feed` gives it." },
        body: { type: "string", description: "Plain text." }
      },
      required: [ "post_id", "body" ]
    )

    def self.call(post_id:, body:, server_context:)
      post = server_context.visibility.visible_posts(::Post.all).find_by(id: post_id)
      return not_found("post") if post.nil?

      comment = post.comments.build(body: body, actor: server_context.actor)
      return refused(comment) unless comment.save

      text "Replied to #{post.excerpt(length: 60)}."
    end

    def self.refused(comment)
      MCP::Tool::Response.new([ { type: "text", text: comment.errors.full_messages.to_sentence } ], error: true)
    end

    private_class_method :refused
  end
end
