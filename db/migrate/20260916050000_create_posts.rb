class CreatePosts < ActiveRecord::Migration[8.1]
  def change
    create_table :posts do |t|
      t.references :actor, null: false, foreign_key: true
      t.string :title
      t.text :body, null: false, default: ""
      # Markdown rendered and sanitised at write time, so no request ever pays
      # for it and no unsanitised HTML is ever a template away from the page.
      t.text :body_html, null: false, default: ""
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
