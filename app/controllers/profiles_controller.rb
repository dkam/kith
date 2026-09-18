class ProfilesController < ApplicationController
  allow_unauthenticated_access only: :show

  before_action :set_actor

  # Two viewers, two templates. The signed-out page has almost nothing in
  # common with the members' one — no follow button, no "follows you", no
  # counts — and writing that as conditionals inside a single template is how
  # a follower count eventually leaks. Followers were promised a private
  # graph; the profile is the obvious place for it to escape.
  def show
    @posts = visibility.visible_posts(@actor.posts).newest_first.limit(20)

    return render_anonymously if visibility.signed_out?

    @follow = current_actor.follow_of(@actor)
    @follows_you = @actor.follow_of(current_actor)
  end

  private
    def set_actor
      @actor = Actor.local.find_by!(handle: params[:handle].to_s.downcase)

      # An invisible member's profile is for their connections. 404 rather than
      # 403: confirming the page exists is the leak. A signed-out visitor gets
      # the same 404 here that a handle nobody has ever used would give them.
      head :not_found unless visibility.profile?(@actor)
    rescue ActiveRecord::RecordNotFound
      head :not_found
    end

    # Cacheable only on this branch. The same URL renders a different body to a
    # a signed-in member — a follow button, and their followers-only posts —
    # and a shared cache knows nothing about anybody's session.
    def render_anonymously
      allow_indexing_by @actor
      expires_in 5.minutes, public: true
      render :anonymous
    end
end
