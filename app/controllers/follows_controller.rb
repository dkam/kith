class FollowsController < ApplicationController
  before_action :set_follow, only: %i[ accept reject destroy ]

  # Ask to follow someone. The edge starts as `requested`; nothing is visible
  # until they accept.
  def create
    # Local only for now. When federation lands this resolves a full handle.
    actor = Actor.local.find_by(handle: params[:handle].to_s.downcase)

    head :not_found and return if actor.nil? || !visibility.profile?(actor)

    @actor = actor
    @follow = Follow.request(current_actor, actor)

    respond_with_button
  end

  # Accepting only ever changes this edge. Following back is a separate,
  # deliberate request — see the button the accept UI offers afterwards.
  def accept
    head :not_found and return unless @follow.followed_actor_id == current_actor.id

    @follow.accept!

    @actor = @follow.follower_actor
    respond_with_request_row
  end

  def reject
    head :not_found and return unless @follow.followed_actor_id == current_actor.id

    @follow.reject!

    @actor = @follow.follower_actor
    respond_with_request_row
  end

  # Unfollowing removes the edge outright. Nothing is soft-deleted, and asking
  # again later should read as a fresh request rather than a revived one.
  def destroy
    head :not_found and return unless @follow.follower_actor_id == current_actor.id

    @actor = @follow.followed_actor
    @follow.destroy
    @follow = nil

    respond_with_button
  end

  private
    def set_follow
      @follow = Follow.find(params[:id])
    rescue ActiveRecord::RecordNotFound
      head :not_found
    end

    def respond_with_button
      respond_to do |format|
        format.turbo_stream { render :button }
        format.html { redirect_back fallback_location: profile_path(@actor.handle) }
      end
    end

    def respond_with_request_row
      respond_to do |format|
        format.turbo_stream
        format.html { redirect_back fallback_location: follows_path }
      end
    end
end
