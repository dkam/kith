# This file is auto-generated from the current state of the database. Instead
# of editing this file, please use the migrations feature of Active Record to
# incrementally modify your database, and then regenerate this schema definition.
#
# This file is the source Rails uses to define your schema when running `bin/rails
# db:schema:load`. When creating a new database, `bin/rails db:schema:load` tends to
# be faster and is potentially less error prone than running all of your
# migrations from scratch. Old migrations may fail to apply correctly if those
# migrations use external dependencies or application code.
#
# It's strongly recommended that you check this file into your version control system.

ActiveRecord::Schema[8.1].define(version: 2026_09_16_024002) do
  create_table "active_storage_attachments", force: :cascade do |t|
    t.bigint "blob_id", null: false
    t.datetime "created_at", null: false
    t.string "name", null: false
    t.bigint "record_id", null: false
    t.string "record_type", null: false
    t.index ["blob_id"], name: "index_active_storage_attachments_on_blob_id"
    t.index ["record_type", "record_id", "name", "blob_id"], name: "index_active_storage_attachments_uniqueness", unique: true
  end

  create_table "active_storage_blobs", force: :cascade do |t|
    t.bigint "byte_size", null: false
    t.string "checksum"
    t.string "content_type"
    t.datetime "created_at", null: false
    t.string "filename", null: false
    t.string "key", null: false
    t.text "metadata"
    t.string "service_name", null: false
    t.index ["key"], name: "index_active_storage_blobs_on_key", unique: true
  end

  create_table "active_storage_variant_records", force: :cascade do |t|
    t.bigint "blob_id", null: false
    t.string "variation_digest", null: false
    t.index ["blob_id", "variation_digest"], name: "index_active_storage_variant_records_uniqueness", unique: true
  end

  create_table "actors", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.integer "discoverable", default: 1, null: false
    t.string "display_name", default: "", null: false
    t.string "domain"
    t.string "handle", null: false
    t.string "inbox_url"
    t.text "private_key"
    t.text "public_key"
    t.string "type", null: false
    t.datetime "updated_at", null: false
    t.index ["handle", "domain"], name: "index_actors_on_handle_and_domain", unique: true
    t.index ["handle"], name: "index_actors_on_local_handle", unique: true, where: "domain IS NULL"
    t.index ["type"], name: "index_actors_on_type"
  end

  create_table "members", force: :cascade do |t|
    t.integer "actor_id", null: false
    t.datetime "created_at", null: false
    t.string "email_address", null: false
    t.integer "inviter_member_id"
    t.string "password_digest", null: false
    t.datetime "updated_at", null: false
    t.index ["actor_id"], name: "index_members_on_actor_id", unique: true
    t.index ["email_address"], name: "index_members_on_email_address", unique: true
    t.index ["inviter_member_id"], name: "index_members_on_inviter_member_id"
  end

  create_table "sessions", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "ip_address"
    t.integer "member_id", null: false
    t.datetime "updated_at", null: false
    t.string "user_agent"
    t.index ["member_id"], name: "index_sessions_on_member_id"
  end

  add_foreign_key "active_storage_attachments", "active_storage_blobs", column: "blob_id"
  add_foreign_key "active_storage_variant_records", "active_storage_blobs", column: "blob_id"
  add_foreign_key "members", "actors"
  add_foreign_key "members", "members", column: "inviter_member_id"
  add_foreign_key "sessions", "members"
end
