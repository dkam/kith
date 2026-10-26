# How a member's rides are trimmed: the radius around each end, and a fixed
# offset — a bearing and a distance — that moves every trim circle off the
# point it protects. See Track::Trim.
#
# The offset is random and stored rather than derived, so that every trim of
# a member's rides, wherever it runs, uses one circle, and so that nothing an
# operator rotates can quietly re-draw it. Existing members are given one here.
class GiveAMemberATrim < ActiveRecord::Migration[8.1]
  def up
    add_column :members, :trim_radius_m, :integer, null: false, default: 500
    add_column :members, :trim_bearing_deg, :float
    add_column :members, :trim_offset_m, :float

    select_values("SELECT id FROM members").each do |id|
      execute sanitize_sql([ "UPDATE members SET trim_bearing_deg = ?, trim_offset_m = ? WHERE id = ?",
        SecureRandom.random_number * 360, 125 + SecureRandom.random_number * 125, id ])
    end

    change_column_null :members, :trim_bearing_deg, false
    change_column_null :members, :trim_offset_m, false
  end

  def down
    remove_column :members, :trim_offset_m
    remove_column :members, :trim_bearing_deg
    remove_column :members, :trim_radius_m
  end

  private
    def sanitize_sql(statement) = ActiveRecord::Base.sanitize_sql_array(statement)
end
