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

ActiveRecord::Schema[7.1].define(version: 2026_02_14_140349) do
  create_table "health_records", force: :cascade do |t|
    t.integer "user_id", null: false
    t.date "recorded_at"
    t.decimal "weight"
    t.decimal "sleep_hours"
    t.integer "exercise_minutes"
    t.integer "mood"
    t.text "notes"
    t.integer "steps"
    t.integer "heart_rate"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.integer "systolic_pressure"
    t.integer "diastolic_pressure"
    t.decimal "body_temperature"
    t.decimal "weather_temperature", precision: 4, scale: 1
    t.integer "weather_humidity"
    t.decimal "weather_pressure", precision: 6, scale: 1
    t.integer "weather_code"
    t.string "weather_description"
    t.index ["user_id"], name: "index_health_records_on_user_id"
  end

  create_table "push_subscriptions", force: :cascade do |t|
    t.integer "user_id", null: false
    t.string "endpoint", null: false
    t.string "p256dh_key", null: false
    t.string "auth_key", null: false
    t.string "user_agent"
    t.boolean "active", default: true, null: false
    t.datetime "last_used_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["endpoint"], name: "index_push_subscriptions_on_endpoint", unique: true
    t.index ["user_id", "active"], name: "index_push_subscriptions_on_user_id_and_active"
    t.index ["user_id"], name: "index_push_subscriptions_on_user_id"
  end

  create_table "users", force: :cascade do |t|
    t.string "email", default: "", null: false
    t.string "encrypted_password", default: "", null: false
    t.string "reset_password_token"
    t.datetime "reset_password_sent_at"
    t.datetime "remember_created_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.decimal "latitude", precision: 10, scale: 7
    t.decimal "longitude", precision: 10, scale: 7
    t.string "location_name"
    t.string "nickname", limit: 20
    t.string "api_token_digest"
    t.index ["api_token_digest"], name: "index_users_on_api_token_digest", unique: true
    t.index ["email"], name: "index_users_on_email", unique: true
    t.index ["reset_password_token"], name: "index_users_on_reset_password_token", unique: true
  end

  create_table "weekly_reports", force: :cascade do |t|
    t.integer "user_id", null: false
    t.date "week_start", null: false
    t.date "week_end", null: false
    t.text "content", null: false
    t.json "summary_data"
    t.json "predictions"
    t.integer "tokens_used"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["user_id", "week_start"], name: "index_weekly_reports_on_user_id_and_week_start", unique: true
    t.index ["user_id"], name: "index_weekly_reports_on_user_id"
  end

  add_foreign_key "health_records", "users"
  add_foreign_key "push_subscriptions", "users"
  add_foreign_key "weekly_reports", "users"
end
