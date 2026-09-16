# There is no public sign up. The only way into Kith is a single-use invite
# from someone already here, which is why every member has an inviter.
class Invite < ApplicationRecord
  LIFETIME = 14.days
  # base58: no 0/O/I/l, because invite codes get read aloud and typed by hand.
  # has_secure_token insists on 24 characters, which is more link than anyone
  # wants to dictate; 16 is ~94 bits, and the invite expires anyway.
  CODE_LENGTH = 16

  belongs_to :inviter_member, class_name: "Member"
  belongs_to :claimed_by_member, class_name: "Member", optional: true

  scope :claimed, -> { where.not(claimed_by_member_id: nil) }
  scope :unclaimed, -> { where(claimed_by_member_id: nil) }
  scope :expired, -> { where(expires_at: ..Time.current) }
  scope :open, -> { unclaimed.where(expires_at: Time.current..) }
  scope :newest_first, -> { order(created_at: :desc) }
  # What an allowance is spent on: invites that brought somebody in, and
  # invites that still might. One that expired unclaimed did neither.
  scope :counting_against_allowance, -> { claimed.or(open) }

  before_validation :set_default_expiry, on: :create
  before_validation :set_code, on: :create

  validates :code, presence: true, uniqueness: true
  validates :expires_at, presence: true

  def claimed? = claimed_by_member_id.present?
  def expired? = expires_at.past?
  def open? = !claimed? && !expired?

  def status
    return :claimed if claimed?
    return :expired if expired?
    :open
  end

  # Spending an invite is a race: two people can open the same link. The
  # conditional update means exactly one of them wins.
  def claim!(member)
    claimed = self.class.unclaimed.where(id: id, expires_at: Time.current..).update_all(claimed_by_member_id: member.id, updated_at: Time.current)
    raise ActiveRecord::RecordInvalid.new(self), "Invite has already been used or has expired" if claimed.zero?

    reload
  end

  private
    def set_default_expiry
      self.expires_at ||= LIFETIME.from_now
    end

    def set_code
      self.code ||= loop do
        candidate = SecureRandom.base58(CODE_LENGTH)
        break candidate unless self.class.exists?(code: candidate)
      end
    end
end
