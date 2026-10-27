# The emitted record: a ride, a scrobble, a checkin. Not written, the way a
# post is, but recorded — see docs/phase-two.md, "The shape". STI on `type`,
# the way actors already do it, with the kind-specific facts in `data`.
class CreateEntries < ActiveRecord::Migration[8.1]
  def change
    create_table :entries do |t|
      t.references :actor, null: false, foreign_key: true, index: false
      t.string :type, null: false
      # When it happened in the world. Not created_at: a Saturday ride imported
      # on Tuesday belongs on Saturday.
      t.datetime :occurred_at, null: false
      # NULL is "imported, not shared", the same trick posts play.
      t.datetime :published_at
      t.integer :audience, null: false, default: 0
      t.references :source, foreign_key: true, index: false
      t.string :external_id
      t.string :uri
      t.json :data, null: false, default: {}

      t.timestamps
    end

    # SQLite treats NULLs as distinct, so entries typed in by hand, with no
    # source, never collide.
    add_index :entries, [ :source_id, :external_id ], unique: true
    add_index :entries, [ :actor_id, :type, :occurred_at ]
  end
end
