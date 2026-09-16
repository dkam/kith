# Two different limits on how Kith grows, answering two different questions.
#
# `members.invite_allowance` is the soft one: how many people any one member
# may bring in, so growth stays spread out rather than arriving all at once
# from whoever is most enthusiastic.
#
# The instance row is the hard one: `invites_open` closes the door outright,
# and `member_cap` closes it automatically once Kith is full. Either overrides
# every allowance, including an admin's.
class AddInviteCaps < ActiveRecord::Migration[8.1]
  def up
    add_column :members, :invite_allowance, :integer, default: 5, null: false

    create_table :instances do |t|
      t.boolean :invites_open, null: false, default: true
      t.integer :member_cap

      t.timestamps
    end

    # There is exactly one, and it exists from the start so that nothing on a
    # read path has to create it.
    execute("INSERT INTO instances (invites_open, created_at, updated_at) VALUES (1, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP)")
  end

  def down
    drop_table :instances
    remove_column :members, :invite_allowance
  end
end
