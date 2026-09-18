class SettingsController < ApplicationController
  def show
    @actor = current_actor
    @mcp_tokens = current_member.mcp_tokens.oldest_first
    @new_mcp_token = McpToken.new
  end

  def update
    @actor = current_actor
    @mcp_tokens = current_member.mcp_tokens.oldest_first
    @new_mcp_token = McpToken.new

    if @actor.update(actor_params)
      redirect_to settings_path, notice: "Saved."
    else
      render :show, status: :unprocessable_content
    end
  end

  private
    # The handle is deliberately absent: it is how other people refer to you,
    # and it will become half of a federated address. Changing it would break
    # links that already exist.
    def actor_params
      params.expect(actor: [ :display_name, :discoverable, :avatar ])
    end
end
