class ApplicationController < ActionController::Base
  include Authentication
  # Only allow modern browsers supporting webp images, web push, badges, import maps, CSS nesting, and CSS :has.
  allow_browser versions: :modern

  # Changes to the importmap will invalidate the etag for HTML responses
  stale_when_importmap_changes

  helper_method :current_instance

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
end
