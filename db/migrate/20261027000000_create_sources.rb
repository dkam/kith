# A member's account on a service: where their entries come from. The first
# kind is a Strava account export, which needs no credential at all — the row
# is there so that (source_id, external_id) makes the next import idempotent.
# The first connector that does need a secret adds its columns, encrypted.
class CreateSources < ActiveRecord::Migration[8.1]
  def change
    create_table :sources do |t|
      t.references :member, null: false, foreign_key: true, index: false
      # Integer-backed and sparse, like posts.audience, so the app and the
      # services that come later fit between.
      t.integer :kind, null: false
      t.json :config, null: false, default: {}
      t.datetime :last_imported_at

      t.timestamps
    end

    add_index :sources, [ :member_id, :kind ], unique: true
  end
end
