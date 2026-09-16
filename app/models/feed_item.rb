# A post, materialised into one reader's feed.
#
# Fan-out on write rather than a query at read time: it is forty people, the
# writes are cheap, and it gives each reader somewhere to keep their own unread
# state without that state leaking into anyone else's view.
class FeedItem < ApplicationRecord
  belongs_to :member
  belongs_to :post

  scope :unread, -> { where(read_at: nil) }
  scope :newest_first, -> { order(posted_at: :desc, id: :desc) }

  # Keyset pagination: everything strictly after the cursor item in the feed's
  # own order. An offset would skip or repeat rows as new posts arrive at the
  # top while someone is reading.
  scope :before, ->(cursor) {
    item = cursor.present? ? find_by(id: cursor) : nil
    next all if item.nil?

    where("posted_at < :posted_at OR (posted_at = :posted_at AND id < :id)", posted_at: item.posted_at, id: item.id)
  }

  def read? = read_at.present?

  def read!
    update_column(:read_at, Time.current) unless read?
  end
end
