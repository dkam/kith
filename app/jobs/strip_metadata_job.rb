# Photographs carry the time, the camera, and often the GPS coordinates of
# where they were taken. None of that should survive an upload.
#
# Direct upload means the original is already in storage by the time the form
# is submitted, so this rewrites it in place afterwards. It is the second of
# two layers: MediaController only ever serves vips-generated variants, which
# carry no metadata either way, so a photo is safe to serve even before this
# job has run.
class StripMetadataJob < ApplicationJob
  queue_as :default

  # SVG is deliberately absent: it is a script-execution vector, not a photo.
  STRIPPABLE_TYPES = %w[ image/jpeg image/png image/webp image/tiff image/heic image/heif ].freeze

  discard_on ActiveRecord::RecordNotFound

  def perform(attachment)
    # The post may have been deleted while this sat in the queue.
    return if attachment.destroyed? || !ActiveStorage::Attachment.exists?(attachment.id)

    blob = attachment.blob
    return unless STRIPPABLE_TYPES.include?(blob.content_type)

    blob.open do |file|
      # Rotate first: stripping the metadata loses the flag that says which way
      # is up.
      stripped = ImageProcessing::Vips
        .source(file)
        .loader(autorotate: true)
        .saver(strip: true)
        .call

      overwrite blob, stripped
    end
  rescue ActiveStorage::FileNotFoundError
    # The post was deleted while this was queued. Nothing to strip.
  end

  private
    # The same blob, with new bytes — not a new blob standing in for it.
    #
    # A photo embedded in a post body is named there by the blob's signed global
    # id, so the blob has to keep its identity: replacing the record and purging
    # the original would leave the body pointing at something that no longer
    # exists, and the post would render with a hole in it.
    def overwrite(blob, io)
      blob.upload io, identify: false
      blob.save!

      # Any variant generated from the original is now stale. There is usually
      # nothing here — this runs within moments of the upload, and variants are
      # only made when someone asks for one.
      blob.variant_records.destroy_all
    end
end
