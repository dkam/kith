# Where a member is, so the few absolute times Kith shows are their own clock.
# On members rather than actors: it is a reading preference that belongs to
# whoever holds the credentials, and a remote actor does no reading here.
class GiveAMemberATimeZone < ActiveRecord::Migration[8.1]
  def change
    add_column :members, :time_zone, :string
  end
end
