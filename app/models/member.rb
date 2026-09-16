# A person with credentials on this instance. Their public identity — handle,
# display name, avatar, discoverability — lives on their Actor, so that posts,
# follows and comments can point at local and remote people alike.
class Member < ApplicationRecord
  has_secure_password

  belongs_to :actor, class_name: "LocalActor"
  belongs_to :inviter_member, class_name: "Member", optional: true

  has_many :sessions, dependent: :destroy
  has_many :invited_members, class_name: "Member", foreign_key: :inviter_member_id, dependent: :nullify

  accepts_nested_attributes_for :actor

  normalizes :email_address, with: ->(e) { e.to_s.strip.downcase }

  validates :email_address, presence: true, format: { with: URI::MailTo::EMAIL_REGEXP }, uniqueness: true
  validates :password, length: { minimum: 8 }, allow_nil: true

  delegate :handle, :display_name, :discoverable, to: :actor

  # The only way a member is created outside the first-member rake task: by
  # claiming an invite. Builds the member and its actor together so that a
  # failure leaves neither behind.
  def self.claim(invite, handle:, display_name:, email_address:, password:, password_confirmation:)
    member = new(email_address:, password:, password_confirmation:, inviter_member: invite&.inviter_member)
    member.build_actor(type: "LocalActor", handle:, display_name: display_name.presence || handle)

    transaction do
      member.save!
      invite&.claim!(member)
    end

    member
  rescue ActiveRecord::RecordInvalid
    member
  end
end
