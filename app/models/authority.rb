# What a member may *do*, in one place — the companion to Visibility, and
# deliberately not the same object.
#
# Visibility answers "is this viewer in the audience?", which is a relation
# between two people: who follows whom, who is connected to whom, who chose to
# be invisible. Authority answers "may this person act on the instance?", which
# comes from their role. The two are kept apart because of one rule:
#
#   A role never widens Visibility.
#
# An admin reads exactly the feed an ordinary member reads. The moment
# `Visibility#post?` grows an `|| admin?`, the privacy model is gone and nobody
# notices for a year. So the dependency runs one way only: Authority asks
# Visibility, and Visibility has never heard of a role.
#
# Which is also why moderation is gated on seeing. A moderator may delete a
# post that is already in front of them — one they were sent, or reached by its
# permalink, or found on a public page. Moderation is not a way *in*.
#
# Construct it with the *member*, or nil for a signed-out visitor. Roles live
# on members, not actors, because only local people have credentials: a remote
# actor has no member and so holds no rank here, ever.
class Authority
  attr_reader :member, :visibility

  def initialize(member)
    @member = member
    @visibility = Visibility.new(member&.actor)
  end

  def signed_out? = member.nil?

  # --- Ranks ----------------------------------------------------------------

  def moderates? = !signed_out? && member.moderates?
  def administers? = !signed_out? && member.administers?
  def owns? = !signed_out? && member.owner?

  # --- Posts ----------------------------------------------------------------

  # Only the author. A moderator may take someone's words down; they may not
  # rewrite them and leave the author's name on top.
  def edit_post?(post)
    authored?(post)
  end

  # The author, or anyone who moderates and can already see it. Nothing is
  # soft-deleted, so this takes the photographs with it.
  def delete_post?(post)
    return false if post.nil? || signed_out?
    return false unless visibility.post?(post)

    authored?(post) || moderates?
  end

  # --- Comments -------------------------------------------------------------

  # Your own reply, any reply on your own post, or — for a moderator — any
  # reply they can see. An invisible member's comment is invisible to a
  # moderator too: it is not there to be deleted.
  def delete_comment?(comment)
    return false if comment.nil? || signed_out?
    return false unless visibility.comment?(comment)

    comment.actor_id == member.actor_id || authored?(comment.post) || moderates?
  end

  # --- Invites --------------------------------------------------------------

  # Two limits, asked in the order they matter. The instance closing its door
  # or filling up overrides every allowance, an admin's and the owner's
  # included — otherwise "no more members" would mean "no more members except
  # the people who decide".
  def issue_invite?
    return false if signed_out?
    return false unless Instance.current.accepting_members?

    member.invites_left.positive?
  end

  # Changing how Kith grows — the door, the cap, anyone's allowance — is an
  # admin's job, and one they can do to themselves: the hard limits above are
  # what stop that mattering.
  def manage_invites? = administers?

  # --- Handing out roles ----------------------------------------------------

  # You may set someone's role only if you outrank both where they are now and
  # where you are putting them, and never your own — so an admin makes
  # moderators, the owner makes admins, and nobody promotes themselves.
  #
  # Ownership is not on the list: since the owner does not outrank an owner,
  # `to: :owner` is always false. Handing over the instance is a deliberate act
  # at the console, not a dropdown.
  def assign_role?(target, to:)
    return false if target.nil? || signed_out?
    return false if target.id == member.id
    return false unless administers?
    # A name that is not a role at all ranks below every role, which would
    # otherwise make it something everybody outranks.
    return false unless Member.roles.key?(to.to_s)

    member.outranks?(target.role) && member.outranks?(to)
  end

  private
    def authored?(post)
      post.present? && !signed_out? && post.actor_id == member.actor_id
    end
end
