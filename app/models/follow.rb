# A directed edge: one actor asking to follow another.
#
# Accepting a follow never creates the reverse edge. "Following back" is a
# separate request, made deliberately. A *connection* — the thing that gates
# profile links and an invisible member's comments — is derived: two accepted
# follows pointing opposite ways.
class Follow < ApplicationRecord
  enum :state, { requested: 0, accepted: 1, rejected: 2 }, validate: true

  belongs_to :follower_actor, class_name: "Actor"
  belongs_to :followed_actor, class_name: "Actor"

  scope :between, ->(follower, followed) { where(follower_actor_id: follower, followed_actor_id: followed) }
  scope :newest_first, -> { order(created_at: :desc) }

  validate :cannot_follow_self
  validates :follower_actor_id, uniqueness: { scope: :followed_actor_id }

  after_update_commit :clear_accepted_at, if: -> { saved_change_to_state? && !accepted? }

  # Idempotent: asking twice does not create a second edge, and does not
  # re-open one that was rejected without the asker saying so.
  def self.request(follower, followed)
    between(follower, followed).first || create(follower_actor: follower, followed_actor: followed)
  end

  def accept!
    update!(state: :accepted, accepted_at: Time.current)
  end

  def reject!
    update!(state: :rejected)
  end

  # The reverse edge, if the other actor has asked to follow back.
  def reciprocal
    self.class.between(followed_actor_id, follower_actor_id).first
  end

  def connection?
    accepted? && !!reciprocal&.accepted?
  end

  private
    def cannot_follow_self
      errors.add(:followed_actor, "can't be you") if follower_actor_id.present? && follower_actor_id == followed_actor_id
    end

    def clear_accepted_at
      update_column(:accepted_at, nil)
    end
end
