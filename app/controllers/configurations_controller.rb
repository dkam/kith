# The phone apps' navigation rules, as Hotwire Native's path configuration.
#
# Answered signed out, because a shell fetches this before anybody has typed a
# password — and cacheable publicly, because no session is consulted and every
# client gets identical bytes. That is the whole of the condition Kith puts on
# `Cache-Control: public`, and this is one of only two places that meets it.
#
# What it discloses is the shape of the routes, which is already in the HTML of
# every page. Nothing here knows who is asking.
class ConfigurationsController < ApplicationController
  allow_unauthenticated_access

  # Named one at a time rather than interpolated. `params[:name]` is already
  # constrained by the route, but a template name that came off the wire is how
  # a path traversal gets written by accident, and there are only ever going to
  # be a handful of these.
  def show
    case params[:name]
    when "ios_v1"     then render_configuration :ios_v1
    when "android_v1" then render_configuration :android_v1
    else head :not_found
    end
  end

  private
    def render_configuration(name)
      expires_in 5.minutes, public: true
      render name, formats: :json
    end
end
