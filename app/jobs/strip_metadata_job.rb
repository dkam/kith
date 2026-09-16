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
    blob = attachment.blob
    return unless STRIPPABLE_TYPES.include?(blob.content_type)

    original = blob

    blob.open do |file|
      # Rotate first: stripping the metadata loses the flag that says which way
      # is up.
      stripped = ImageProcessing::Vips
        .source(file)
        .loader(autorotate: true)
        .saver(strip: true)
        .call

      attachment.update!(blob: ActiveStorage::Blob.create_and_upload!(
        io: stripped,
        filename: blob.filename,
        content_type: blob.content_type,
        identify: false
      ))
    end

    original.purge_later
  rescue ActiveStorage::FileNotFoundError
    # The post was deleted while this was queued. Nothing to strip.
  end
end
