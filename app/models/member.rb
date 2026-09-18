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
  has_many :mcp_tokens, dependent: :destroy
  has_many :notifications, dependent: :delete_all
  has_many :invited_members, class_name: "Member", foreign_key: :inviter_member_id, dependent: :nullify

  accepts_nested_attributes_for :actor

  normalizes :email_address, with: ->(e) { e.to_s.strip.downcase }

  validates :email_address, presence: true, format: { with: URI::MailTo::EMAIL_REGEXP }, uniqueness: true
  validates :password, length: { minimum: 8 }, allow_nil: true

  delegate :handle, :display_name, :discoverable, to: :actor

  # Password resets happen in the console. There is no mail flow and, for a few
  # dozen friends, there does not need to be one: the operator is reachable.
  #
  #   Member.reset_password! "alice@example.com"   # => a new random password
  #   Member.reset_password! "@alice", "correct horse battery staple"
  #
  # Takes an email address or a handle, and makes a password up if you do not
  # give it one. Returns the new password, so the console prints it.
  def self.reset_password!(identifier, password = nil)
    find_by_identifier!(identifier).reset_password!(password)
  end

  # Whichever of the two things the operator has to hand: the address they mail
  # the person at, or the handle they know them by.
  def self.find_by_identifier!(identifier)
    given = identifier.to_s.strip.downcase.delete_prefix("@")

    find_by(email_address: given) ||
      LocalActor.find_by(handle: given)&.member ||
      raise(ActiveRecord::RecordNotFound, "No member with the email address or handle #{identifier.inspect}")
  end

  # Signs the member out everywhere as well, because a password is usually
  # being reset for one of two reasons, and one of them is that somebody else
  # knows the old one.
  def reset_password!(password = nil)
    password ||= SecureRandom.alphanumeric(24)

    update!(password: password, password_confirmation: password)
    sessions.destroy_all

    password
  end

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
    member = new(email_address:, password:, password_confirmation:)
    member.build_actor(type: "LocalActor", handle: handle, display_name: display_name.presence || handle, discoverable: :everyone)

    if exists?
      member.errors.add(:base, "Kith already has a member. Ask them for an invite.")
    else
      member.save
    end

    member
  end
end
