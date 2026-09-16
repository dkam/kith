# Roles say what a member may *do* to this instance. They deliberately say
# nothing about what a member may *see*: that is Visibility's job, and a role
# never widens it. See Authority.
class AddRoleToMembers < ActiveRecord::Migration[8.1]
  def up
    add_column :members, :role, :integer, default: 0, null: false
    add_index :members, :role

    # Whoever claimed the instance owns it. On an instance that already has
    # members, that is the earliest of them — the one with no inviter.
    first_member_id = select_value("SELECT id FROM members ORDER BY id LIMIT 1")
    execute("UPDATE members SET role = 20 WHERE id = #{first_member_id.to_i}") if first_member_id
  end

  def down
    remove_column :members, :role
  end
end
