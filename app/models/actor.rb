# Anything that can author a post or be followed: a member of this instance, a
# person on another Kith or ActivityPub server, or a syndication feed.
#
# Subclasses are LocalActor, RemoteActor and FeedActor. Nothing but LocalActor
# exists in phase 1, but the seam is here so federation does not require a
# migration of every foreign key in the app.
class Actor < ApplicationRecord
  HANDLE_FORMAT = /\A[a-z0-9_]{2,32}\z/

  enum :discoverable, { everyone: 0, connections_only: 1, invisible: 2 }, validate: true

  has_one :member, dependent: :destroy

  has_many :posts, dependent: :destroy

  has_many :outgoing_follows, class_name: "Follow", foreign_key: :follower_actor_id, dependent: :destroy
  has_many :incoming_follows, class_name: "Follow", foreign_key: :followed_actor_id, dependent: :destroy

  has_many :followees, -> { merge(Follow.accepted) }, through: :outgoing_follows, source: :followed_actor
  has_many :followers, -> { merge(Follow.accepted) }, through: :incoming_follows, source: :follower_actor
  has_one_attached :avatar

  normalizes :handle, with: ->(handle) { handle.to_s.strip.downcase.delete_prefix("@") }
  normalizes :domain, with: ->(domain) { domain.presence&.strip&.downcase }

  validates :handle, presence: true, format: { with: HANDLE_FORMAT, message: "may only contain lowercase letters, numbers and underscores" }
  validates :handle, uniqueness: { scope: :domain, case_sensitive: false }
  validates :display_name, length: { maximum: 80 }

  scope :local, -> { where(domain: nil) }

  def local? = domain.nil?
  def remote? = !local?

  # "alice" locally, "alice@example.social" for anyone else.
  def full_handle = local? ? handle : "#{handle}@#{domain}"

  def to_s = display_name.presence || "@#{handle}"

  def to_param = handle

  # A connection is derived, never stored: both actors follow each other and
  # both follows are accepted. Accepting a follow never implies the reverse.
  def connected_to?(other)
    return false if other.nil? || other.id == id

    Follow.accepted.between(id, other.id).exists? && Follow.accepted.between(other.id, id).exists?
  end

  def follows?(other)
    other.present? && Follow.accepted.between(id, other.id).exists?
  end

  def follow_of(other)
    other && outgoing_follows.between(id, other.id).first
  end

  # Whose posts this actor may see: its own, plus everyone it has been accepted
  # to follow.
  def visible_author_ids
    [ id ] + Follow.accepted.where(follower_actor_id: id).pluck(:followed_actor_id)
  end
end
