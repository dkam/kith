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
  has_many :invited_members, class_name: "Member", foreign_key: :inviter_member_id, dependent: :nullify

  accepts_nested_attributes_for :actor

  normalizes :email_address, with: ->(e) { e.to_s.strip.downcase }

  validates :email_address, presence: true, format: { with: URI::MailTo::EMAIL_REGEXP }, uniqueness: true
  validates :password, length: { minimum: 8 }, allow_nil: true

  delegate :handle, :display_name, :discoverable, to: :actor

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
end
