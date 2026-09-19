class ApplicationController < ActionController::Base
  include Authentication
  include HotwireNative

  # Only allow modern browsers supporting webp images, web push, badges, import
  # maps, CSS nesting, and CSS :has.
  #
  # The phone apps are exempt, and not as a courtesy. A WKWebView reports no
  # `Version/` token of its own, so whatever Hotwire Native appends to the user
  # agent is what `useragent` reads as the Safari version — `…; version/1.0`
  # parses as Safari 1.0, and every screen in the app becomes
  # public/406-unsupported-browser.html with no browser chrome to escape from.
  # An Android device whose System WebView has not updated fails the same way
  # for a real reason rather than a punctuation one. Either way the app pins its
  # own WebView floor at build time, and this check has nothing left to add.
  #
  # It has to be `unless:` rather than a skip: `allow_browser` registers an
  # anonymous lambda, so `skip_before_action` has nothing to name.
  allow_browser versions: :modern, unless: :hotwire_native_app?

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
