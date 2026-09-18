# Resetting the endpoint. There is no "view" of a token beyond the settings
# page, and no way to get the old value back.
class McpTokensController < ApplicationController
  def update
    current_member.mcp_token!.rotate!

    redirect_to settings_path, notice: "New endpoint. The old one has stopped working — paste the new one into anything that was using it."
  end
end
