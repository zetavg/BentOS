# This file is auto-generated from the current state of the database. Instead
# of editing this file, please use the migrations feature of Active Record to
# incrementally modify your database, and then regenerate this schema definition.
#
# This file is the source Rails uses to define your schema when running `rails
# db:schema:load`. When creating a new database, `rails db:schema:load` tends to
# be faster and is potentially less error prone than running all of your
# migrations from scratch. Old migrations may fail to apply correctly if those
# migrations use external dependencies or application code.
#
# It's strongly recommended that you check this file into your version control system.

ActiveRecord::Schema.define(version: 2020_07_25_000004) do

  # These are extensions that must be enabled in order to support this database
  enable_extension "pgcrypto"
  enable_extension "plpgsql"

  create_table "accounting_user_authorization_holds", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.uuid "user_id", null: false
    t.string "state", limit: 32, null: false
    t.bigint "amount_subunit", null: false
    t.string "transfer_code", null: false
    t.string "partner_account_identifier", null: false
    t.string "partner_account_scope_identity"
    t.bigint "capture_line_id"
    t.string "detail_type"
    t.uuid "detail_id"
    t.jsonb "metadata"
    t.datetime "created_at", precision: 6, null: false
    t.datetime "updated_at", precision: 6, null: false
    t.index ["capture_line_id"], name: "index_accounting_user_authorization_holds_on_capture_line_id"
    t.index ["detail_type", "detail_id"], name: "index_accounting_user_authorization_holds_on_detail"
    t.index ["state"], name: "index_accounting_user_authorization_holds_on_state"
    t.index ["user_id"], name: "index_accounting_user_authorization_holds_on_user_id"
  end

  create_table "double_entry_account_balances", force: :cascade do |t|
    t.string "account", null: false
    t.string "scope"
    t.bigint "balance", null: false
    t.datetime "created_at", precision: 6, null: false
    t.datetime "updated_at", precision: 6, null: false
    t.index ["account"], name: "index_account_balances_on_account"
    t.index ["scope", "account"], name: "index_account_balances_on_scope_and_account", unique: true
  end

  create_table "double_entry_line_checks", force: :cascade do |t|
    t.bigint "last_line_id", null: false
    t.boolean "errors_found", null: false
    t.text "log"
    t.datetime "created_at", precision: 6, null: false
    t.datetime "updated_at", precision: 6, null: false
    t.index ["created_at", "last_line_id"], name: "line_checks_created_at_last_line_id_idx"
  end

  create_table "double_entry_lines", force: :cascade do |t|
    t.string "account", null: false
    t.string "scope"
    t.string "code", null: false
    t.bigint "amount", null: false
    t.bigint "balance", null: false
    t.bigint "partner_id"
    t.string "partner_account", null: false
    t.string "partner_scope"
    t.string "detail_type"
    t.uuid "detail_id"
    t.jsonb "metadata"
    t.datetime "created_at", precision: 6, null: false
    t.datetime "updated_at", precision: 6, null: false
    t.index ["account", "code", "created_at"], name: "lines_account_code_created_at_idx"
    t.index ["account", "created_at"], name: "lines_account_created_at_idx"
    t.index ["scope", "account", "created_at"], name: "lines_scope_account_created_at_idx"
    t.index ["scope", "account", "id"], name: "lines_scope_account_id_idx"
  end

  create_table "user_oauth_authentications", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.uuid "user_id"
    t.string "provider", null: false
    t.string "uid", null: false
    t.string "access_token"
    t.datetime "access_token_expires_at"
    t.string "refresh_token"
    t.jsonb "data"
    t.boolean "sync_data", default: false, null: false
    t.datetime "created_at", precision: 6, null: false
    t.datetime "updated_at", precision: 6, null: false
    t.index ["provider", "uid"], name: "index_user_oauth_authentications_on_provider_and_uid", unique: true
    t.index ["user_id"], name: "index_user_oauth_authentications_on_user_id"
  end

  create_table "users", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.string "name"
    t.text "picture_url"
    t.string "email", null: false
    t.string "encrypted_password"
    t.string "reset_password_token"
    t.datetime "reset_password_sent_at"
    t.datetime "remember_created_at"
    t.integer "sign_in_count", default: 0, null: false
    t.datetime "current_sign_in_at"
    t.datetime "last_sign_in_at"
    t.inet "current_sign_in_ip"
    t.inet "last_sign_in_ip"
    t.string "confirmation_token"
    t.datetime "confirmed_at"
    t.datetime "confirmation_sent_at"
    t.string "unconfirmed_email"
    t.integer "failed_attempts", default: 0, null: false
    t.string "unlock_token"
    t.datetime "locked_at"
    t.datetime "created_at", precision: 6, null: false
    t.datetime "updated_at", precision: 6, null: false
    t.index ["confirmation_token"], name: "index_users_on_confirmation_token", unique: true
    t.index ["email"], name: "index_users_on_email", unique: true
    t.index ["reset_password_token"], name: "index_users_on_reset_password_token", unique: true
    t.index ["unlock_token"], name: "index_users_on_unlock_token", unique: true
  end

  add_foreign_key "accounting_user_authorization_holds", "double_entry_lines", column: "capture_line_id"
  add_foreign_key "accounting_user_authorization_holds", "users"
  add_foreign_key "user_oauth_authentications", "users"
end
