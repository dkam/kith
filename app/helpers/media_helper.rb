module MediaHelper
  # The only way an attachment becomes a URL. Deliberately the only helper that
  # knows how: nothing else should be able to produce an image src.
  def media_url_for(attachment, variant: AttachableMedia::DEFAULT_VARIANT)
    media_path(AttachableMedia.signed_id(attachment), variant)
  end

  def media_image_tag(attachment, variant: AttachableMedia::DEFAULT_VARIANT, **options)
    image_tag media_url_for(attachment, variant: variant), **options
  end

  def avatar_tag(actor, size: :thumb, css_class: "avatar size-10")
    if actor.avatar.attached?
      media_image_tag actor.avatar.attachment, variant: size, alt: "", class: css_class, loading: "lazy"
    else
      tag.span actor.to_s.first.upcase,
        class: "#{css_class} inline-flex items-center justify-center text-sm font-medium text-quiet",
        aria: { hidden: true }
    end
  end

  # The body as the editor needs it.
  #
  # Post#forget_attachment_urls drops the blob URL Lexxy sent with each photo
  # before the body is stored, so a stored body names its photographs by signed
  # global id and by nothing else. The editor still has to draw them, so the
  # URLs are put back here — as media URLs, which MediaController will re-check
  # before it serves anything.
  #
  # Handing the form a String rather than the rich text record also stops Lexxy
  # server-rendering the attachments into the markup a second time.
  def editable_body_html(post)
    return "" unless post.body.body

    attachments = post.body.embeds_attachments.select(&:persisted?).index_by(&:blob_id)

    post.body.body.fragment.replace(ActionText::Attachment.tag_name) do |node|
      blob = ActionText::Attachable.from_node(node)
      attachment = attachments[blob.try(:id)]
      node["url"] = media_url_for(attachment) if attachment
      node
    end.to_html
  end
end
