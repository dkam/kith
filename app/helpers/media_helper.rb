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
end
