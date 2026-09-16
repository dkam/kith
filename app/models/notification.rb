# Telling someone that something happened.
#
# Notifications are the classic side channel: "Carol commented on your post" is
# a disclosure even when the comment itself is hidden. So nothing here is
# rendered without passing the same Visibility check as the feed, and the
# unread count is derived from the visible set rather than from the table.
class Notification < ApplicationRecord
  enum :kind, { new_follower: 0, follow_accepted: 1, new_comment: 2 }, validate: true

  belongs_to :member
  belongs_to :actor
  belongs_to :subject, polymorphic: true

  scope :unread, -> { where(read_at: nil) }
  scope :newest_first, -> { order(id: :desc) }

  validates :member_id, uniqueness: { scope: %i[ subject_type subject_id kind ] }

  # Delivers to the member behind an actor, if there is one — remote actors
  # have no inbox here. Never notifies someone about their own doing.
  def self.deliver(kind, to:, from:, about:)
    return if to.nil? || from.nil? || to.id == from.id

    member = Member.find_by(actor_id: to.id)
    return if member.nil?

    create(member: member, actor: from, subject: about, kind: kind)
  rescue ActiveRecord::RecordNotUnique
    nil
  end

  def read? = read_at.present?
  def unread? = !read?

  def read!
    update_column(:read_at, Time.current) unless read?
  end
end
