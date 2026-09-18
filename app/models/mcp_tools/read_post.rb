module McpTools
  # One post in full, with the comments the caller is allowed to see.
  #
  # The lookup goes through Visibility's *scope* rather than Post.find plus a
  # predicate, so a permalink and a feed cannot come to hold different opinions
  # about the same post. A post the caller may not see answers exactly as a
  # post that was never written does.
  class ReadPost < Tool
    tool_name "post"
    title "Read a Kith post"
    description "One post in full — title, author, body and its comments — by the id the `feed` tool gives."
    read_only "Read a Kith post"
    input_schema(
      properties: {
        id: { type: "integer", description: "The post's id." }
      },
      required: [ "id" ]
    )

    def self.call(id:, server_context:)
      post = server_context.visibility.visible_posts(Post.readable).find_by(id: id)
      return not_found("post") if post.nil?

      text [ heading(post), body_of(post), comments_on(post, server_context.visibility) ].compact_blank.join("\n\n")
    end

    def self.heading(post)
      [
        post.title.presence,
        "#{post.actor} (@#{post.handle}) · #{post.published_at.to_fs(:long)} · #{post.audience}"
      ].compact.join("\n")
    end

    # to_plain_text renders an embedded photograph as "[IMG_1137.jpeg]", which
    # is a camera's filename rather than a sentence — the same thing
    # Post#excerpt refuses to say. Take the photographs out of the prose and
    # then name them in words, in the place they were.
    def self.body_of(post)
      return nil if post.body.body.nil?

      prose = post.body.body.fragment
        .update { |source| source.css(ActionText::Attachment.tag_name).each(&:remove) }
        .to_plain_text.strip

      [ prose.presence, photo_note(post) ].compact.join("\n\n")
    end

    def self.photo_note(post)
      case post.photo_count
      when 0 then nil
      when 1 then "(One photograph.)"
      else "(#{post.photo_count} photographs.)"
      end
    end

    def self.comments_on(post, visibility)
      comments = visibility.visible_comments(post).includes(:actor).to_a
      return nil if comments.empty?

      [ "Comments (#{comments.size}):" ]
        .concat(comments.map { |comment| "— #{comment.actor}: #{comment.body}" })
        .join("\n")
    end

    private_class_method :heading, :body_of, :photo_note, :comments_on
  end
end
