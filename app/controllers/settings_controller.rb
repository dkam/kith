class SettingsController < ApplicationController
  def show
    @actor = current_actor
  end

  def update
    @actor = current_actor

    if @actor.update(actor_params)
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
      params.expect(actor: [ :display_name, :discoverable, :avatar ])
    end
end
