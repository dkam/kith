# The privacy model, in one place.
#
# Every feed, permalink, comment, notification and image request answers its
# "may this person see this?" question here. There is deliberately no second
# path: a rule that lives in two places is a rule that will disagree with
# itself, and the notification side channel is the classic way private posts
# leak.
#
# Construct it with the *viewer's actor*, or nil for a signed-out visitor.
class Visibility
  attr_reader :viewer

  def initialize(viewer)
    @viewer = viewer
  end

  def signed_out? = viewer.nil?

  # --- Posts ---------------------------------------------------------------

  # A draft is asked about first, because it is the one case where the audience
  # says nothing at all: a post nobody has published belongs to its author
  # alone, public or not. It is an intention, not a promise.
  #
  # Public posts are readable by anyone, including people with no account —
  # they are the only thing that will ever leave this instance.
  #
  # Everything else is readable by its author, and by actors whose follow of
  # the author has been accepted. A pending or rejected follow sees nothing.
  def post?(post)
    return false if post.nil?
    return post.actor_id == viewer&.id if post.draft?
    return true if post.audience_public?
    return false if signed_out?
    return true if post.actor_id == viewer.id

    viewer.follows?(post.actor)
  end

  # The same rule, as a query. Use this rather than filtering in Ruby: the feed
  # and a profile page must not be able to disagree with #post?.
  def visible_posts(scope = Post.all)
    return scope.publicly_visible if signed_out?

    posted = scope.live.where(actor_id: viewer.visible_author_ids).or(scope.publicly_visible)
    posted.or(scope.drafts.where(actor_id: viewer.id))
  end

  # --- Profile links -------------------------------------------------------

  # A commenter's name is always shown. Whether it is a *link* — an invitation
  # to go and look at who they are — is gated.
  #
  # You may follow the link if it is your own, if you are connected to them
  # (mutual accepted follows), or if they have chosen to be discoverable by
  # everyone. `connections_only` and `invisible` differ elsewhere; for the link
  # itself they are the same answer.
  def profile_link?(actor)
    return false if actor.nil? || signed_out?
    return true if actor.id == viewer.id
    return true if actor.everyone?

    viewer.connected_to?(actor)
  end

  # Whether the viewer may open the profile page at all, as opposed to merely
  # seeing a link to it. An invisible member's profile is for their connections
  # only.
  def profile?(actor)
    return false if actor.nil? || signed_out?
    return true if actor.id == viewer.id
    return true unless actor.invisible?

    viewer.connected_to?(actor)
  end

  # --- Comments ------------------------------------------------------------

  # A comment is visible when its post is — and then, separately, an invisible
  # member's comments are shown only to their connections. Someone who has
  # chosen to be invisible should not be surfaced to strangers by the act of
  # replying to a mutual friend.
  def comment?(comment)
    return false if comment.nil?
    return false unless post?(comment.post)

    commenter_visible?(comment.actor)
  end

  def visible_comments(post)
    return Comment.none unless post?(post)

    hidden = hidden_commenter_ids
    hidden.any? ? post.comments.where.not(actor_id: hidden) : post.comments
  end

  # --- Notifications -------------------------------------------------------

  # Notifications pass the identical check as the feed, because they are the
  # classic side channel: "Carol commented on your post" is a leak if Carol's
  # comment is not one you may see.
  def notification?(notification)
    return false if notification.nil? || signed_out?
    return false unless notification.member_id == viewer.member&.id

    case notification.subject
    when Comment then comment?(notification.subject)
    when Post then post?(notification.subject)
    when Follow then follow?(notification.subject)
    else notification.subject.present?
    end
  end

  # --- Media ---------------------------------------------------------------

  # Attachments inherit the visibility of what they hang off. An avatar is
  # visible to any member — names and faces are shown throughout — while a
  # photo is exactly as private as the post whose body it is embedded in.
  def attachment?(attachment)
    case attachment&.record
    when ActionText::RichText then post?(AttachableMedia.post_for(attachment))
    when Actor then !signed_out?
    else false
    end
  end

  private
    def follow?(follow)
      follow.follower_actor_id == viewer.id || follow.followed_actor_id == viewer.id
    end

    def commenter_visible?(actor)
      return false if actor.nil?
      return true if actor.id == viewer&.id
      return true unless actor.invisible?

      viewer.present? && viewer.connected_to?(actor)
    end

    # Invisible actors whose comments this viewer may not see: everyone
    # invisible, less the viewer and their connections.
    def hidden_commenter_ids
      invisible = Actor.invisible.pluck(:id)
      return invisible if signed_out?

      invisible - [ viewer.id ] - connected_actor_ids
    end

    def connected_actor_ids
      @connected_actor_ids ||= begin
        followed = Follow.accepted.where(follower_actor_id: viewer.id).pluck(:followed_actor_id)
        Follow.accepted.where(follower_actor_id: followed, followed_actor_id: viewer.id).pluck(:follower_actor_id)
      end
    end
end
