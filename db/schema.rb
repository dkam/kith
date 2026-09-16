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

ActiveRecord::Schema[8.1].define(version: 2026_09_17_010000) do
  create_table "action_text_rich_texts", force: :cascade do |t|
    t.text "body"
    t.datetime "created_at", null: false
    t.string "name", null: false
    t.bigint "record_id", null: false
    t.string "record_type", null: false
    t.datetime "updated_at", null: false
    t.index ["record_type", "record_id", "name"], name: "index_action_text_rich_texts_uniqueness", unique: true
  end

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

  create_table "comments", force: :cascade do |t|
    t.integer "actor_id", null: false
    t.text "body", null: false
    t.datetime "created_at", null: false
    t.integer "post_id", null: false
    t.datetime "updated_at", null: false
    t.index ["actor_id"], name: "index_comments_on_actor_id"
    t.index ["post_id", "created_at"], name: "index_comments_on_post_id_and_created_at"
    t.index ["post_id"], name: "index_comments_on_post_id"
  end

  create_table "feed_items", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.integer "member_id", null: false
    t.integer "post_id", null: false
    t.datetime "posted_at", null: false
    t.datetime "read_at"
    t.datetime "updated_at", null: false
    t.index ["member_id", "post_id"], name: "index_feed_items_on_member_id_and_post_id", unique: true
    t.index ["member_id", "posted_at", "id"], name: "index_feed_items_on_member_id_and_posted_at_and_id", order: { posted_at: :desc, id: :desc }
    t.index ["member_id", "read_at"], name: "index_feed_items_on_member_id_and_read_at"
    t.index ["member_id"], name: "index_feed_items_on_member_id"
    t.index ["post_id"], name: "index_feed_items_on_post_id"
  end

  create_table "follows", force: :cascade do |t|
    t.datetime "accepted_at"
    t.datetime "created_at", null: false
    t.integer "followed_actor_id", null: false
    t.integer "follower_actor_id", null: false
    t.integer "state", default: 0, null: false
    t.datetime "updated_at", null: false
    t.index ["followed_actor_id", "state"], name: "index_follows_on_followed_actor_id_and_state"
    t.index ["followed_actor_id"], name: "index_follows_on_followed_actor_id"
    t.index ["follower_actor_id", "followed_actor_id"], name: "index_follows_on_follower_actor_id_and_followed_actor_id", unique: true
    t.index ["follower_actor_id", "state"], name: "index_follows_on_follower_actor_id_and_state"
    t.index ["follower_actor_id"], name: "index_follows_on_follower_actor_id"
  end

  create_table "instances", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.boolean "invites_open", default: true, null: false
    t.integer "member_cap"
    t.datetime "updated_at", null: false
  end

  create_table "invites", force: :cascade do |t|
    t.integer "claimed_by_member_id"
    t.string "code", null: false
    t.datetime "created_at", null: false
    t.datetime "expires_at", null: false
    t.integer "inviter_member_id", null: false
    t.datetime "updated_at", null: false
    t.index ["claimed_by_member_id"], name: "index_invites_on_claimed_by_member_id"
    t.index ["code"], name: "index_invites_on_code", unique: true
    t.index ["inviter_member_id"], name: "index_invites_on_inviter_member_id"
  end

  create_table "members", force: :cascade do |t|
    t.integer "actor_id", null: false
    t.datetime "created_at", null: false
    t.string "email_address", null: false
    t.integer "invite_allowance", default: 5, null: false
    t.integer "inviter_member_id"
    t.string "password_digest", null: false
    t.integer "role", default: 0, null: false
    t.string "time_zone"
    t.datetime "updated_at", null: false
    t.index ["actor_id"], name: "index_members_on_actor_id", unique: true
    t.index ["email_address"], name: "index_members_on_email_address", unique: true
    t.index ["inviter_member_id"], name: "index_members_on_inviter_member_id"
    t.index ["role"], name: "index_members_on_role"
  end

  create_table "notifications", force: :cascade do |t|
    t.integer "actor_id", null: false
    t.datetime "created_at", null: false
    t.integer "kind", null: false
    t.integer "member_id", null: false
    t.datetime "read_at"
    t.integer "subject_id", null: false
    t.string "subject_type", null: false
    t.datetime "updated_at", null: false
    t.index ["actor_id"], name: "index_notifications_on_actor_id"
    t.index ["member_id", "id"], name: "index_notifications_on_member_id_and_id", order: { id: :desc }
    t.index ["member_id", "read_at"], name: "index_notifications_on_member_id_and_read_at"
    t.index ["member_id", "subject_type", "subject_id", "kind"], name: "index_notifications_on_member_and_subject_and_kind", unique: true
    t.index ["member_id"], name: "index_notifications_on_member_id"
    t.index ["subject_type", "subject_id"], name: "index_notifications_on_subject"
  end

  create_table "posts", force: :cascade do |t|
    t.integer "actor_id", null: false
    t.integer "audience", default: 0, null: false
    t.text "body", default: "", null: false
    t.text "body_html", default: "", null: false
    t.datetime "created_at", null: false
    t.datetime "published_at"
    t.boolean "remote", default: false, null: false
    t.string "title"
    t.datetime "updated_at", null: false
    t.string "uri"
    t.index ["actor_id", "published_at"], name: "index_posts_on_actor_id_and_published_at"
    t.index ["actor_id"], name: "index_posts_on_actor_id"
    t.index ["published_at"], name: "index_posts_on_published_at"
    t.index ["uri"], name: "index_posts_on_uri", unique: true
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
  add_foreign_key "comments", "actors"
  add_foreign_key "comments", "posts"
  add_foreign_key "feed_items", "members"
  add_foreign_key "feed_items", "posts"
  add_foreign_key "follows", "actors", column: "followed_actor_id"
  add_foreign_key "follows", "actors", column: "follower_actor_id"
  add_foreign_key "invites", "members", column: "claimed_by_member_id"
  add_foreign_key "invites", "members", column: "inviter_member_id"
  add_foreign_key "members", "actors"
  add_foreign_key "members", "members", column: "inviter_member_id"
  add_foreign_key "notifications", "actors"
  add_foreign_key "notifications", "members"
  add_foreign_key "posts", "actors"
  add_foreign_key "sessions", "members"
end
