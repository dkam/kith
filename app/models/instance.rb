# This Kith, as a thing with settings — one row, always. For now it holds only
# the two hard limits on growth; the instance's name, description and its own
# actor will live here when there is federation to need them.
class Instance < ApplicationRecord
  validates :member_cap, numericality: { only_integer: true, greater_than: 0 }, allow_nil: true

  # Not memoized on the class: that outlives a request, a test and a code
  # reload, and this is one indexed read of one row.
  def self.current = first || create!

  def full? = member_cap.present? && Member.count >= member_cap

  # The door, as one question. An allowance is only ever consulted after this
  # has said yes, so closing the instance closes it for everyone — an admin
  # included.
  def accepting_members? = invites_open? && !full?

  def closed_because
    return nil if accepting_members?
    return "Kith is full — #{member_cap} #{"member".pluralize(member_cap)}." if full?

    "Invites are closed."
  end
end
