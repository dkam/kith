class ApplicationController < ActionController::Base
  include Authentication
  # Only allow modern browsers supporting webp images, web push, badges, import maps, CSS nesting, and CSS :has.
  allow_browser versions: :modern

  # Changes to the importmap will invalidate the etag for HTML responses
  stale_when_importmap_changes

  helper_method :indexable?

  private
    # Kith is `noindex, nofollow` everywhere. A page opts out of that only when
    # both things are true: the visitor has no account — so what they are being
    # shown is already the public version — and the author has climbed to the
    # `internet` rung, which is where "search engines will find them" is
    # written on the tin.
    #
    # Being readable and being findable are not the same grant. A public post
    # by a `connections_only` author stays reachable to anyone holding the
    # link and stays out of the index, which is the difference between
    # unlisted and published.
    def allow_indexing_by(actor)
      @indexable = visibility.signed_out? && actor&.internet?
    end

    def indexable? = @indexable.present?
end
