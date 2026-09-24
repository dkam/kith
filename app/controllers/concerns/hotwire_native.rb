# The phone apps read the same Kith the web does. This is the whole of what the
# server knows about them.
#
# `hotwire_native_app?` comes from turbo-rails, which includes
# Turbo::Native::Navigation into every controller for us; it matches
# "Hotwire Native" or "Turbo Native" in the user agent. All this concern does is
# turn that one predicate into a request variant, so a template can differ by
# being a second file rather than by a conditional — the same bargain
# `profiles/anonymous` makes.
module HotwireNative
  extend ActiveSupport::Concern

  included do
    before_action :set_hotwire_native_variant

    # Insurance, not a fix for anything today. Nothing in Kith calls
    # `fresh_when` or `stale?` yet, so no etagger — this one or the one
    # `stale_when_importmap_changes` adds — is consulted. The moment something
    # does, the app and the web would agree on an ETag while disagreeing about
    # the body, because `EtagWithTemplateDigest` digests the action's template
    # and the layout is the only thing that differs.
    etag { :hotwire_native if hotwire_native_app? }
  end

  private
    def set_hotwire_native_variant
      request.variant = :hotwire_native if hotwire_native_app?
    end
end
