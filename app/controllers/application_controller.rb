class ApplicationController < ActionController::Base
  include Authentication
  # Only allow modern browsers supporting webp images, web push, badges, import maps, CSS nesting, and CSS :has.
  allow_browser versions: :modern

  # Changes to the importmap will invalidate the etag for HTML responses
  stale_when_importmap_changes

  helper_method :current_instance

  before_action :identify_for_error_reporting

  private
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
