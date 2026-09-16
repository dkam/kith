# A syndication feed (RSS/Atom) we poll and render as posts. Not created in
# phase 1.
class FeedActor < Actor
  validates :domain, presence: true
end
