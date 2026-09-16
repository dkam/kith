class CreateActors < ActiveRecord::Migration[8.1]
  def change
    create_table :actors do |t|
      # Single-table inheritance: LocalActor, RemoteActor, FeedActor.
      t.string :type, null: false
      t.string :handle, null: false
      # NULL for actors that live on this instance.
      t.string :domain
      t.string :display_name, null: false, default: ""
      t.string :inbox_url
      t.text :public_key
      # Local actors only, encrypted at rest.
      t.text :private_key
      t.integer :discoverable, null: false, default: 1

      t.timestamps
    end

    add_index :actors, [ :handle, :domain ], unique: true
    # SQLite treats NULLs as distinct, so the composite index above does not
    # constrain local actors. This one does.
    add_index :actors, :handle, unique: true, where: "domain IS NULL", name: "index_actors_on_local_handle"
    add_index :actors, :type
  end
end
