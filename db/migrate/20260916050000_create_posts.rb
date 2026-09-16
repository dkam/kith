class CreatePosts < ActiveRecord::Migration[8.1]
  def change
    create_table :posts do |t|
      t.references :actor, null: false, foreign_key: true
      t.string :title
      # The body is an Action Text rich text, not a column: it is HTML written
      # in the editor, and it owns the photos embedded in it.
      # Fixed when the post is written and never changed. Circles come later.
      t.integer :audience, null: false, default: 0
      t.datetime :published_at, null: false
      # The ActivityPub id, once there is federation. NULL for local posts.
      t.string :uri
      t.boolean :remote, null: false, default: false

      t.timestamps
    end

    add_index :posts, [ :actor_id, :published_at ]
    add_index :posts, :published_at
    add_index :posts, :uri, unique: true
  end
end
