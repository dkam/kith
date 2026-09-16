class CreateMembers < ActiveRecord::Migration[8.1]
  def change
    create_table :members do |t|
      t.references :actor, null: false, foreign_key: true, index: { unique: true }
      t.string :email_address, null: false
      t.string :password_digest, null: false
      # NULL only for the first member, created by rake kith:first_member.
      t.references :inviter_member, foreign_key: { to_table: :members }

      t.timestamps
    end

    add_index :members, :email_address, unique: true
  end
end
