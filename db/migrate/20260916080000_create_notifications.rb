class CreateNotifications < ActiveRecord::Migration[8.1]
  def change
    create_table :notifications do |t|
      # Who is being told.
      t.references :member, null: false, foreign_key: true
      # Who caused it. An actor, not a member: this will arrive from other
      # servers eventually.
      t.references :actor, null: false, foreign_key: true
      t.references :subject, null: false, polymorphic: true
      # new_follower and follow_accepted both point at a Follow and are
      # otherwise indistinguishable.
      t.integer :kind, null: false
      t.datetime :read_at

      t.timestamps
    end

    add_index :notifications, [ :member_id, :id ], order: { id: :desc }
    add_index :notifications, [ :member_id, :read_at ]
    # One notification per member per event: accepting twice, or a double-
    # submitted follow, should not ring the bell twice.
    add_index :notifications, [ :member_id, :subject_type, :subject_id, :kind ], unique: true,
      name: "index_notifications_on_member_and_subject_and_kind"
  end
end
