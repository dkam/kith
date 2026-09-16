class ProfilesController < ApplicationController
  before_action :set_actor

  def show
    @posts = visibility.visible_posts(@actor.posts).live.newest_first.limit(20)
    # Through Visibility like everything else, even though the only actor this
    # can return anything for is the viewer themselves.
    @drafts = visibility.visible_posts(@actor.posts).drafts.order(created_at: :desc, id: :desc)
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
