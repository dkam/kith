class CreateFeedItems < ActiveRecord::Migration[8.1]
  def change
    create_table :feed_items do |t|
      t.references :member, null: false, foreign_key: true
      t.references :post, null: false, foreign_key: true
      t.datetime :read_at
      # Copied from the post. The feed is ordered by when something was
      # written, not by when it happened to be fanned out — otherwise
      # back-filling an accepted follow drops old posts at the top of the page.
      t.datetime :posted_at, null: false

      t.timestamps
    end

    # One row per reader per post; the reader's unread state lives here.
    add_index :feed_items, [ :member_id, :post_id ], unique: true
    # The feed itself, and the keyset it pages through.
    add_index :feed_items, [ :member_id, :posted_at, :id ], order: { posted_at: :desc, id: :desc }
    add_index :feed_items, [ :member_id, :read_at ]
  end
end
