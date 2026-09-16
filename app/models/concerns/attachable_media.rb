# The three sizes Kith serves, and the opaque ids MediaController accepts.
#
# Every variant is re-encoded by vips with metadata stripped, so nothing that
# leaves the server carries EXIF — not even before StripMetadataJob has
# rewritten the original.
module AttachableMedia
  VARIANTS = {
    thumb: { resize_to_limit: [ 160, 160 ] },
    feed: { resize_to_limit: [ 1200, 1200 ] },
    full: { resize_to_limit: [ 2400, 2400 ] }
  }.freeze

  DEFAULT_VARIANT = :feed

  def self.transformation_for(variant)
    VARIANTS.fetch(variant.to_sym).merge(saver: { strip: true, quality: 82 })
  end

  def self.variant?(name)
    VARIANTS.key?(name.to_s.to_sym)
  end

  # Active Storage signs *blobs*, and ActiveStorage::Attachment#signed_id is
  # delegated to its blob — which identifies the file, not the attachment that
  # hangs it off a particular post. Visibility is a property of the attachment,
  # so media gets its own opaque id, signed with its own key.
  #
  # It is an identifier, not a capability: it says which attachment is being
  # asked for, and MediaController still has to decide whether the person
  # asking may have it.
  def self.signed_id(attachment)
    verifier.generate(attachment.id)
  end

  def self.find_attachment!(signed_id)
    ActiveStorage::Attachment.find(verifier.verify(signed_id))
  end

  # Action Text renders an embedded photo through a partial that is handed the
  # blob and nothing else, but a media id is signed from the attachment. One
  # query per photo, which is the price of not signing the blob: the same file
  # embedded in two posts is two attachments with two audiences, and a blob id
  # could not say which one was being asked for.
  def self.attachment_for_blob(blob)
    ActiveStorage::Attachment.find_by(
      blob_id: blob.id, record_type: "ActionText::RichText", name: "embeds"
    )
  end

  # The post an attachment belongs to, or nil. A photo hangs off the rich text
  # body rather than off the post directly, and visibility is a property of the
  # post — so this is the one place that walks from a file back to it.
  def self.post_for(attachment)
    record = attachment&.record
    return unless record.is_a?(ActionText::RichText)

    record.record if record.record.is_a?(Post)
  end

  def self.verifier
    @verifier ||= ActiveSupport::MessageVerifier.new(
      Rails.application.key_generator.generate_key("kith/media"),
      digest: "SHA256",
      serializer: JSON,
      url_safe: true
    )
  end
end
