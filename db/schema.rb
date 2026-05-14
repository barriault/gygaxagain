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

ActiveRecord::Schema[8.1].define(version: 2026_05_14_155217) do
  # These are extensions that must be enabled in order to support this database
  enable_extension "pg_catalog.plpgsql"

  create_table "campaigns", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.text "description"
    t.string "name", null: false
    t.datetime "updated_at", null: false
    t.bigint "user_id", null: false
    t.index "user_id, lower((name)::text)", name: "index_campaigns_on_user_id_and_lower_name", unique: true
    t.index ["user_id"], name: "index_campaigns_on_user_id"
  end

  create_table "faction_secrets", force: :cascade do |t|
    t.text "content", null: false
    t.datetime "created_at", null: false
    t.bigint "faction_id", null: false
    t.string "label", null: false
    t.datetime "updated_at", null: false
    t.index ["faction_id"], name: "index_faction_secrets_on_faction_id"
  end

  create_table "factions", force: :cascade do |t|
    t.bigint "campaign_id", null: false
    t.datetime "created_at", null: false
    t.string "name", null: false
    t.text "public_description"
    t.datetime "updated_at", null: false
    t.index "campaign_id, lower((name)::text)", name: "index_factions_on_campaign_id_and_lower_name", unique: true
    t.index ["campaign_id"], name: "index_factions_on_campaign_id"
  end

  create_table "llm_calls", force: :cascade do |t|
    t.integer "cache_creation_tokens", default: 0, null: false
    t.integer "cache_read_tokens", default: 0, null: false
    t.bigint "campaign_id"
    t.datetime "created_at", null: false
    t.integer "input_tokens", default: 0, null: false
    t.integer "latency_ms"
    t.string "model", null: false
    t.integer "output_tokens", default: 0, null: false
    t.jsonb "prompt_payload", default: {}, null: false
    t.string "provider", null: false
    t.string "provider_request_id"
    t.string "purpose", null: false
    t.jsonb "response_payload", default: {}, null: false
    t.bigint "scene_id"
    t.integer "total_cost_cents", default: 0, null: false
    t.datetime "updated_at", null: false
    t.bigint "user_id", null: false
    t.index ["campaign_id"], name: "index_llm_calls_on_campaign_id"
    t.index ["provider", "model"], name: "index_llm_calls_on_provider_and_model"
    t.index ["purpose", "created_at"], name: "index_llm_calls_on_purpose_and_created_at"
    t.index ["scene_id"], name: "index_llm_calls_on_scene_id"
    t.index ["user_id"], name: "index_llm_calls_on_user_id"
  end

  create_table "npcs", force: :cascade do |t|
    t.bigint "campaign_id", null: false
    t.datetime "created_at", null: false
    t.string "location"
    t.string "name", null: false
    t.text "public_description"
    t.datetime "updated_at", null: false
    t.index ["campaign_id"], name: "index_npcs_on_campaign_id"
  end

  create_table "users", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.datetime "current_sign_in_at"
    t.string "current_sign_in_ip"
    t.string "email", default: "", null: false
    t.string "encrypted_password", default: "", null: false
    t.integer "failed_attempts", default: 0, null: false
    t.bigint "last_played_campaign_id"
    t.datetime "last_sign_in_at"
    t.string "last_sign_in_ip"
    t.datetime "locked_at"
    t.datetime "remember_created_at"
    t.datetime "reset_password_sent_at"
    t.string "reset_password_token"
    t.integer "sign_in_count", default: 0, null: false
    t.string "unlock_token"
    t.datetime "updated_at", null: false
    t.index ["email"], name: "index_users_on_email", unique: true
    t.index ["last_played_campaign_id"], name: "index_users_on_last_played_campaign_id"
    t.index ["reset_password_token"], name: "index_users_on_reset_password_token", unique: true
    t.index ["unlock_token"], name: "index_users_on_unlock_token", unique: true
  end

  add_foreign_key "campaigns", "users", on_delete: :cascade
  add_foreign_key "faction_secrets", "factions", on_delete: :cascade
  add_foreign_key "factions", "campaigns", on_delete: :cascade
  add_foreign_key "llm_calls", "campaigns", on_delete: :cascade
  add_foreign_key "llm_calls", "users", on_delete: :cascade
  add_foreign_key "npcs", "campaigns", on_delete: :cascade
  add_foreign_key "users", "campaigns", column: "last_played_campaign_id", on_delete: :nullify
end
