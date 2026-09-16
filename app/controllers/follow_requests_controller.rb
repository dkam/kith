# The list of people waiting on you, and the people you have asked.
class FollowRequestsController < ApplicationController
  def index
    @requests = current_actor.incoming_follows.requested.includes(:follower_actor).newest_first
    @pending = current_actor.outgoing_follows.requested.includes(:followed_actor).newest_first
    @following = current_actor.outgoing_follows.accepted.includes(:followed_actor).newest_first
    @followers = current_actor.incoming_follows.accepted.includes(:follower_actor).newest_first
  end
end
