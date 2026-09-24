class SettingsController < ApplicationController
  def show
    @actor = current_actor
    @member = current_member
    @mcp_tokens = current_member.mcp_tokens.oldest_first
    @new_mcp_token = McpToken.new
  end

  # One form, two records: who you are is on your actor, where you are is on
  # your member. Both or neither — half a saved form is worse than none.
  def update
    @actor = current_actor
    @member = current_member
    @mcp_tokens = current_member.mcp_tokens.oldest_first
    @new_mcp_token = McpToken.new

    @actor.assign_attributes(actor_params)
    @member.assign_attributes(member_params)

    if save_together
      redirect_to settings_path, notice: "Saved."
    else
      render :show, status: :unprocessable_content
    end
  end

  # Nothing is soft-deleted: the file goes, not a flag.
  def destroy_avatar
    current_actor.avatar.purge
    redirect_to settings_path, notice: "Photo removed."
  end

  private
    # The handle is deliberately absent: it is how other people refer to you,
    # and it will become half of a federated address. Changing it would break
    # links that already exist.
    def actor_params
      return {} unless params.key?(:actor)

      params.expect(actor: [ :display_name, :discoverable, :avatar ])
    end

    # Everything a member may change about their own reading of Kith. The
    # actor's half is above; email and password have their own paths.
    def member_params
      return {} unless params.key?(:member)

      params.expect(member: [ :time_zone ])
    end

    # The actor first, so that a bad time zone leaves its error on the member
    # and a bad name leaves its error on the actor, rather than both objects
    # carrying the same complaint through autosave.
    def save_together
      Member.transaction do
        raise ActiveRecord::Rollback unless @actor.save && @member.save

        true
      end
    end
end
