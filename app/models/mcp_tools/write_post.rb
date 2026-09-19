module McpTools
  # Writing a post, from an endpoint that is allowed to.
  #
  # The body arrives as plain text and is turned into paragraphs here. Kith
  # stores HTML because the editor produces HTML, but nothing is gained by
  # letting an agent hand us markup to store — so it doesn't get to.
  #
  # Photographs are not offered. A photo has to be uploaded, stripped of its
  # EXIF and embedded in the prose where its author put it, and none of that is
  # a thing to do down a JSON-RPC call.
  class WritePost < Tool
    tool_name "write_post"
    title "Write a Kith post"
    description <<~TEXT
      Write a post as this member. The body is plain text; a blank line starts a
      new paragraph. Photographs can't be added this way.

      Audience is fixed when the post is written and can never be changed
      afterwards. `followers` means the people whose follow you've accepted;
      they can comment. `public` means anyone on the internet, and other servers
      can keep copies.
    TEXT
    annotations(read_only_hint: false, destructive_hint: false, idempotent_hint: false, open_world_hint: false,
      title: "Write a Kith post")
    input_schema(
      properties: {
        title: { type: "string", description: "Optional. A post can be untitled." },
        body: { type: "string", description: "Plain text. A blank line starts a new paragraph." },
        audience: { type: "string", enum: %w[ followers public ], description: "Who may read it. Defaults to followers." }
      },
      required: [ "body" ]
    )

    def self.call(body:, server_context:, title: nil, audience: "followers")
      post = ::Post.new(actor: server_context.actor, title: title, audience: audience, body: ::Post.paragraphs(body))

      return refused(post) unless post.save

      text "Posted. #{post_line(post)}"
    end

    def self.refused(post)
      MCP::Tool::Response.new([ { type: "text", text: post.errors.full_messages.to_sentence } ], error: true)
    end

    private_class_method :refused
  end
end
