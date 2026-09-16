class CreateFollows < ActiveRecord::Migration[8.1]
  def change
    create_table :follows do |t|
      t.references :follower_actor, null: false, foreign_key: { to_table: :actors }
      t.references :followed_actor, null: false, foreign_key: { to_table: :actors }
      t.integer :state, null: false, default: 0
      t.datetime :accepted_at

      t.timestamps
    end

    # One edge per ordered pair. A follows B and B follows A are two rows.
    add_index :follows, [ :follower_actor_id, :followed_actor_id ], unique: true
    add_index :follows, [ :followed_actor_id, :state ]
    add_index :follows, [ :follower_actor_id, :state ]
  end
end
