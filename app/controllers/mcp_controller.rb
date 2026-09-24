# The endpoint an agent talks to. One member, one token, read-only.
#
# It is the only controller in the app that does not resume a session: the
# token in the URL is the credential, and it stands for exactly one member. The
# session cookie is deliberately ignored even when one is present, so the
# endpoint cannot be driven by a browser that happens to be signed in as
# somebody else.
#
# It descends from ActionController::API rather than ApplicationController for
# the same reason: no cookies, no CSRF token, no browser version to vouch for,
# and no view layer to render into.
class McpController < ActionController::API
  before_action :authenticate_token

  # JSON-RPC over HTTP POST. A notification has no reply, which the spec
  # answers with 202 and an empty body.
  def create
    response_body = McpServer.for(@token).handle_json(request.raw_post)

    if response_body.nil?
      head :accepted
    else
      render json: response_body
    end
  end

  # Streamable HTTP lets a client open a GET for a server-initiated stream.
  # Kith has nothing to say unprompted, and the spec's answer for that is 405.
  def show
    head :method_not_allowed
  end

  private
    # As everywhere else: a credential that isn't ours and a URL that was never
    # issued give the same answer.
    def authenticate_token
      # Silenced because the lookup puts the token in a WHERE clause, and
      # development logs SQL. The request line and the parameters are already
      # filtered — `token` is in config.filter_parameters — and this is the one
      # place the value would still have reached a log file.
      @token = ActiveRecord::Base.logger.silence { McpToken.authenticate(presented_token) }

      return head :not_found if @token.nil?

      @token.touch_last_used
    end

    # In the query string because that is the only place a token can ride that
    # every MCP client accepts — phone apps included — and because Rails
    # already filters a parameter called `token` out of the logs. The bearer
    # header is accepted too, for clients that can send one.
    def presented_token
      bearer_token || params[:token]
    end

    def bearer_token
      request.authorization.to_s[/\ABearer (.+)\z/, 1]
    end
end
