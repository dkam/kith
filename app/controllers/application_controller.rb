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

  helper_method :current_instance, :indexable?

  before_action :identify_for_error_reporting
  around_action :in_the_readers_time_zone

  private
    # Nearly every time Kith shows is relative — "3 hours ago" is the same
    # sentence everywhere. The few absolute ones belong to whoever is reading,
    # so the whole request runs in their zone and no view has to remember to
    # convert. A signed-out visitor, or a member who has not said where they
    # are, gets the instance's own clock.
    def in_the_readers_time_zone(&block)
      Time.use_zone(current_member&.zone || Time.zone, &block)
    end

    # Which member a crash report belongs to, when there is a reporter to tell
    # and a member to name. ErrorReport decides how much of them goes.
    def identify_for_error_reporting
      Sentry.set_user(ErrorReport.identity(current_member)) if Sentry.initialized? && current_member
    end

    # This Kith's own settings — the door, and the cap on it. One read a
    # request, shared by Authority, the controllers and the views.
    def current_instance
      @current_instance ||= Instance.current
    end

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
