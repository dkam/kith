# The emitted record: a ride, one day a scrobble or a checkin. Not written, the
# way a post is, but recorded — and so imported greedily and shown to nobody
# until its owner says so. See docs/phase-two.md, "The shape".
#
# STI on `type`, as actors are. What is particular to each kind is in `data`.
class Entry < ApplicationRecord
  # The same values as posts', from the same place, so that `public` means one
  # thing across the app.
  include Audience

  belongs_to :actor
  belongs_to :source, optional: true

  scope :live, -> { where.not(published_at: nil) }
  scope :drafts, -> { where(published_at: nil) }

  validates :occurred_at, presence: true

  # A draft is an entry nobody has shared, exactly as a post is a draft: the
  # missing timestamp is the whole fact. An imported entry starts as one.
  def draft? = published_at.nil?
  def published? = !draft?
end
