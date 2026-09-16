class CreateInvites < ActiveRecord::Migration[8.1]
  def change
    create_table :invites do |t|
      t.string :code, null: false
      t.references :inviter_member, null: false, foreign_key: { to_table: :members }
      # Set when the invite is spent. Single use: this is never cleared.
      t.references :claimed_by_member, foreign_key: { to_table: :members }
      t.datetime :expires_at, null: false

      t.timestamps
    end

    add_index :invites, :code, unique: true
  end
end
