# Issuing, resetting and revoking a member's endpoints. There is no view of a
# token beyond the settings page, and no way to get an old value back.
class McpTokensController < ApplicationController
  before_action :set_token, only: %i[ update destroy ]

  def create
    token = current_member.mcp_tokens.build(mcp_token_params)

    if token.save
      redirect_to settings_path, notice: "Endpoint made. Copy it now — it's on this page whenever you need it again."
    else
      redirect_to settings_path, alert: token.errors.full_messages.to_sentence
    end
  end

  # Reset. What it may do is not up for changing; only the value is.
  def update
    @token.rotate!

    redirect_to settings_path, notice: "New endpoint. The old one has stopped working — paste the new one into anything that was using it."
  end

  def destroy
    @token.destroy

    redirect_to settings_path, notice: "Revoked. Anything still holding it has stopped working."
  end

  private
    # Scoped to the member: somebody else's endpoint is not theirs to reset.
    def set_token
      @token = current_member.mcp_tokens.find(params[:id])
    rescue ActiveRecord::RecordNotFound
      head :not_found
    end

    # `access` is here because it is set at issue, and nowhere else because it
    # is never changed afterwards.
    def mcp_token_params
      params.expect(mcp_token: [ :name, :access ])
    end
end
