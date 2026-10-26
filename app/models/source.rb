# A member's account on a service: where their entries come from. On members
# rather than actors because only local people hold accounts, and one per kind,
# because a second Strava export is the same account again, not another one.
#
# A Strava export holds no credential at all — it is a file the member hands
# over — so this row exists to key the next import: an entry's (source_id,
# external_id) is what makes running it again idempotent.
class Source < ApplicationRecord
  # Integer-backed and sparse, like posts.audience: the app, the phone and the
  # services that come later go between.
  enum :kind, { strava_export: 0 }, validate: true

  belongs_to :member

  # Nullified rather than destroyed: an entry is its actor's, and a published
  # one has been read. Nothing is soft-deleted, but nor does losing the account
  # it came from take a ride away from the people who saw it.
  has_many :entries, dependent: :nullify

  validates :kind, uniqueness: { scope: :member_id }
end
