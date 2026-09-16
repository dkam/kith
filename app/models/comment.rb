# Flat. There is no threading, and there will not be: a reply to a reply is a
# conversation forty people can have in one column.
#
# Comments are plain text, not Markdown. A comment is a sentence to a friend,
# and the smaller the surface the less there is to sanitise.
class Comment < ApplicationRecord
  BODY_LIMIT = 4_000

  belongs_to :post
  belongs_to :actor

  scope :chronological, -> { order(created_at: :asc, id: :asc) }

  validates :body, presence: true, length: { maximum: BODY_LIMIT }

  delegate :display_name, to: :actor
end
