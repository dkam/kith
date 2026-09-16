# A person with credentials on this instance. Their public identity — handle,
# display name, avatar, discoverability — lives on their Actor, so that posts,
# follows and comments can point at local and remote people alike.
class Member < ApplicationRecord
  has_secure_password

  belongs_to :actor, class_name: "LocalActor"
  belongs_to :inviter_member, class_name: "Member", optional: true

  has_many :sessions, dependent: :destroy
  has_many :issued_invites, class_name: "Invite", foreign_key: :inviter_member_id, dependent: :destroy
  has_one :claimed_invite, class_name: "Invite", foreign_key: :claimed_by_member_id, dependent: :nullify
  has_many :feed_items, dependent: :delete_all
  has_many :notifications, dependent: :delete_all
  has_many :invited_members, class_name: "Member", foreign_key: :inviter_member_id, dependent: :nullify

  accepts_nested_attributes_for :actor

  # What a member may *do* to this instance. Deliberately not what they may
  # *see*: that is Visibility, and a role never widens it. The powers each rank
  # carries are spelled out in Authority, which is the only thing that should
  # be asking about them.
  #
  # Ranked, so every role carries what the one below it carries, with gaps left
  # for a rank we have not needed yet.
  enum :role, { member: 0, moderator: 5, admin: 10, owner: 20 },
    default: :member, validate: { message: "is not a valid role" }

  normalizes :email_address, with: ->(e) { e.to_s.strip.downcase }

  validates :email_address, presence: true, format: { with: URI::MailTo::EMAIL_REGEXP }, uniqueness: true
  validates :password, length: { minimum: 8 }, allow_nil: true
  validate :an_owner_remains, on: :update

  delegate :handle, :display_name, :discoverable, to: :actor

  # Ranks compare, so `administers?` is true of the owner as well as an admin.
  # Ask these rather than `admin?`: a check written against one exact role is a
  # check that forgets about everyone above it.
  def rank = self.class.rank_of(role)
  def outranks?(other_role) = rank > self.class.rank_of(other_role)
  def moderates? = rank >= self.class.rank_of(:moderator)
  def administers? = rank >= self.class.rank_of(:admin)

  # How much of their allowance a member has spent, and how much is left. An
  # invite that expired unclaimed costs nothing: it brought nobody in and now
  # never will. Lowering an allowance below what is already spent leaves zero
  # rather than a negative, because it cannot take anybody back out again.
  def invites_spent = issued_invites.counting_against_allowance.count
  def invites_left = [ invite_allowance - invites_spent, 0 ].max

  # -1 for anything that is not a role at all, so an unknown name can never
  # come out looking like a rank that somebody outranks.
  def self.rank_of(name) = roles.fetch(name.to_s, -1)

  # The only way a member is created outside the first-member rake task: by
  # claiming an invite. The member, its actor and the spending of the invite
  # all happen in one transaction, so a failure anywhere leaves nothing behind
  # and does not burn the invite.
  #
  # Returns the member, persisted on success and carrying errors on failure.
  def self.claim(invite, handle:, display_name:, email_address:, password:, password_confirmation:)
    member = new(email_address:, password:, password_confirmation:, inviter_member: invite.inviter_member)
    member.build_actor(type: "LocalActor", handle: handle, display_name: display_name.presence || handle)

    transaction do
      member.save!
      invite.claim!(member)
    rescue ActiveRecord::RecordInvalid => e
      # claim! lost the race for an invite someone else just spent.
      member.errors.add(:base, "That invite has been used already, or has expired.") if e.record == invite
      raise ActiveRecord::Rollback
    end

    member
  end

  # The other way in, and only while nobody has taken it: whoever can read the
  # setup code off the server's console. The first member has no inviter.
  #
  # The emptiness check and the insert are not atomic — SQLite has no row to
  # lock before the first one exists — but the only person who can lose that
  # race is someone who already holds the console code, which is to say the
  # operator, twice.
  def self.create_first(handle:, display_name:, email_address:, password:, password_confirmation:)
    member = new(email_address:, password:, password_confirmation:, role: :owner)
    member.build_actor(type: "LocalActor", handle: handle, display_name: display_name.presence || handle, discoverable: :everyone)

    if exists?
      member.errors.add(:base, "Kith already has a member. Ask them for an invite.")
    else
      member.save
    end

    member
  end

  private
    # Kith can hold two owners; it cannot hold none. Stepping down is fine once
    # somebody else has the keys. This is a validation rather than a
    # `before_destroy` on purpose: `Member.destroy_all` from the console is the
    # operator resetting the instance, not an owner being locked out of it.
    def an_owner_remains
      return unless role_changed? && role_was == "owner"
      return if self.class.owner.where.not(id: id).exists?

      errors.add(:role, "would leave Kith with no owner")
    end
end
