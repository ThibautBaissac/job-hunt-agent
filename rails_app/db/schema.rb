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

ActiveRecord::Schema[8.1].define(version: 2025_11_15_141529) do
  # These are extensions that must be enabled in order to support this database
  enable_extension "pg_catalog.plpgsql"

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

  create_table "cvs", force: :cascade do |t|
    t.boolean "active", default: false, null: false
    t.jsonb "analysis_forces", default: [], null: false
    t.jsonb "analysis_suggestions", default: [], null: false
    t.text "analysis_summary"
    t.jsonb "analysis_weaknesses", default: [], null: false
    t.datetime "analyzed_at"
    t.text "body_text", null: false
    t.datetime "created_at", null: false
    t.string "import_method", null: false
    t.string "source_filename"
    t.string "title"
    t.datetime "updated_at", null: false
    t.bigint "user_id", null: false
    t.index ["user_id", "active"], name: "index_cvs_on_user_id_and_active", unique: true, where: "active"
    t.index ["user_id"], name: "index_cvs_on_user_id"
  end

  create_table "job_offers", force: :cascade do |t|
    t.datetime "analyzed_at"
    t.string "company_name", null: false
    t.string "contract_type"
    t.datetime "created_at", null: false
    t.jsonb "keywords", default: [], null: false
    t.string "location"
    t.text "raw_description", null: false
    t.string "seniority_level"
    t.string "source", default: "other", null: false
    t.string "source_url"
    t.text "summary"
    t.jsonb "tech_stack", default: [], null: false
    t.string "title", null: false
    t.datetime "updated_at", null: false
    t.bigint "user_id", null: false
    t.index ["created_at"], name: "index_job_offers_on_created_at"
    t.index ["source"], name: "index_job_offers_on_source"
    t.index ["user_id"], name: "index_job_offers_on_user_id"
  end

  create_table "profiles", force: :cascade do |t|
    t.string "ai_tone", default: "neutral", null: false
    t.string "city"
    t.datetime "created_at", null: false
    t.text "default_signature"
    t.string "full_name"
    t.string "github_url"
    t.string "language", default: "fr", null: false
    t.string "linkedin_url"
    t.string "title"
    t.datetime "updated_at", null: false
    t.bigint "user_id", null: false
    t.index ["user_id"], name: "index_profiles_on_user_id"
  end

  create_table "users", force: :cascade do |t|
    t.datetime "confirmation_sent_at"
    t.string "confirmation_token"
    t.datetime "confirmed_at"
    t.datetime "created_at", null: false
    t.string "email", default: "", null: false
    t.string "encrypted_password", default: "", null: false
    t.boolean "gmail_connected", default: false, null: false
    t.text "google_access_token"
    t.text "google_refresh_token"
    t.datetime "google_token_expires_at"
    t.string "google_uid"
    t.datetime "remember_created_at"
    t.datetime "reset_password_sent_at"
    t.string "reset_password_token"
    t.string "unconfirmed_email"
    t.datetime "updated_at", null: false
    t.index ["confirmation_token"], name: "index_users_on_confirmation_token", unique: true
    t.index ["email"], name: "index_users_on_email", unique: true
    t.index ["google_uid"], name: "index_users_on_google_uid", unique: true
    t.index ["reset_password_token"], name: "index_users_on_reset_password_token", unique: true
  end

  add_foreign_key "active_storage_attachments", "active_storage_blobs", column: "blob_id"
  add_foreign_key "active_storage_variant_records", "active_storage_blobs", column: "blob_id"
  add_foreign_key "cvs", "users"
  add_foreign_key "job_offers", "users"
  add_foreign_key "profiles", "users"
end
