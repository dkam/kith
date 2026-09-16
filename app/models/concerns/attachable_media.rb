# The three sizes Kith serves. Every variant is re-encoded by vips with
# metadata stripped, so nothing leaves the server carrying EXIF.
module AttachableMedia
  extend ActiveSupport::Concern

  VARIANTS = {
    thumb: { resize_to_limit: [ 160, 160 ] },
    feed: { resize_to_limit: [ 1200, 1200 ] },
    full: { resize_to_limit: [ 2400, 2400 ] }
  }.freeze

  DEFAULT_VARIANT = :feed

  def self.transformation_for(variant)
    VARIANTS.fetch(variant.to_sym).merge(strip: true, saver: { strip: true, quality: 82 })
  end

  def self.variant?(name)
    VARIANTS.key?(name.to_s.to_sym)
  end
end
