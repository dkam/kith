class ProfilesController < ApplicationController
  before_action :set_actor

  def show
    @posts = visibility.visible_posts(@actor.posts).newest_first.limit(20)
    @follow = current_actor.follow_of(@actor)
    @follows_you = @actor.follow_of(current_actor)
  end

  private
    def set_actor
      @actor = Actor.local.find_by!(handle: params[:handle].to_s.downcase)

      # An invisible member's profile is for their connections. 404 rather than
      # 403: confirming the page exists is the leak.
      head :not_found unless visibility.profile?(@actor)
    rescue ActiveRecord::RecordNotFound
      head :not_found
    end
end
