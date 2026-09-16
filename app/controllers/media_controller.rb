# The only route by which an image reaches a browser.
#
# Active Storage's own blob URLs are signed but not authorised: the signature
# says "this is a real attachment", not "you may look at it". A link pasted into
# a group chat would work for anyone. So blob URLs are never rendered (see
# resolve_model_to_route in config/application.rb), and every image comes
# through here, where the post's audience is re-checked against the current
# member at request time.
class MediaController < ApplicationController
  allow_unauthenticated_access only: :show

  # An unauthorised request gets 404, not 403. A 403 confirms the attachment
  # exists, which is itself a leak: it tells you your guess was right.
  rescue_from ActiveSupport::MessageVerifier::InvalidSignature,
              ActiveRecord::RecordNotFound,
              ActiveStorage::FileNotFoundError,
              with: :not_found

  def show
    attachment = AttachableMedia.find_attachment!(params[:signed_id])

    return not_found unless AttachableMedia.variant?(params[:variant])
    return not_found unless visibility.attachment?(attachment)

    set_cache_headers attachment
    send_variant attachment.blob, params[:variant], filename: attachment.filename
  end

  # A photograph the editor has uploaded but no post has claimed yet.
  #
  # Lexxy previews an upload from Active Storage's own blob URL, which is a
  # permanent, unauthenticated link to the file — and it goes on working long
  # after the photo has been published to twelve people. This is the same
  # picture with two differences: you have to be signed in, and it stops
  # answering the moment the photo belongs to a post, from which point the
  # post's audience is the only thing that decides.
  def pending
    blob = ActiveStorage::Blob.find_signed!(params[:signed_id])

    return not_found if blob.attachments.any?

    response.headers["Cache-Control"] = "private, no-store"
    send_variant blob, AttachableMedia::DEFAULT_VARIANT, filename: blob.filename
  end

  private
    def send_variant(blob, variant_name, filename:)
      variant = blob.variant(AttachableMedia.transformation_for(variant_name)).processed

      send_data variant.download,
        type: variant.blob.content_type,
        disposition: :inline,
        filename: filename.to_s
    end

    # Private media must not be written to a shared cache, nor left in the
    # browser's disk cache for the next person at the keyboard. Public posts'
    # media is the one thing we do let caches keep.
    def set_cache_headers(attachment)
      if public_media?(attachment)
        expires_in 1.week, public: true
      else
        response.headers["Cache-Control"] = "private, no-store"
        response.headers["Vary"] = "Cookie"
      end
    end

    def public_media?(attachment)
      AttachableMedia.post_for(attachment)&.audience_public?
    end

    def not_found
      head :not_found
    end
end
