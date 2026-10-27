# One run of StravaExport from the settings page: the zip a member uploaded,
# the job that read it, and what came of it. The zip itself is never kept.
class CreateStravaImports < ActiveRecord::Migration[8.1]
  def change
    create_table :strava_imports do |t|
      t.references :member, null: false, foreign_key: true, index: false
      t.integer :state, null: false, default: 0
      t.json :result, null: false, default: {}
      t.datetime :finished_at

      t.timestamps
    end

    add_index :strava_imports, [ :member_id, :created_at ]
    # One import at a time per member, held by the database as well as the
    # model, so two form posts in the same instant cannot both start one.
    # 0 and 10 are queued and running: see StravaImport.
    add_index :strava_imports, :member_id, unique: true, where: "state IN (0, 10)",
      name: "index_strava_imports_one_unfinished_per_member"
  end
end
