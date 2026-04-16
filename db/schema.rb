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

ActiveRecord::Schema[8.1].define(version: 2024_00_01_000005) do
  # These are extensions that must be enabled in order to support this database
  enable_extension "pg_catalog.plpgsql"
  enable_extension "pgcrypto"

  create_table "idempotency_keys", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.datetime "created_at", null: false
    t.datetime "expires_at", null: false
    t.string "key", null: false
    t.string "payment_id"
    t.string "request_path", null: false
    t.jsonb "response_body", default: "{}", null: false
    t.integer "response_status", null: false
    t.datetime "updated_at", null: false
    t.index ["expires_at"], name: "index_idempotency_keys_on_expires_at"
    t.index ["key"], name: "index_idempotency_keys_on_key", unique: true
  end

  create_table "payment_attempts", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.integer "attempt_number", default: 1, null: false
    t.datetime "created_at", null: false
    t.jsonb "metadata", default: {}
    t.uuid "payment_id", null: false
    t.string "processor_response"
    t.string "status", null: false
    t.datetime "updated_at", null: false
    t.index ["payment_id", "attempt_number"], name: "index_payment_attempts_on_payment_id_and_attempt_number"
    t.index ["payment_id"], name: "index_payment_attempts_on_payment_id"
  end

  create_table "payments", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.string "amount", null: false
    t.datetime "authorized_at"
    t.datetime "captured_at"
    t.datetime "created_at", null: false
    t.string "currency", default: "USD", null: false
    t.string "customer_email", null: false
    t.string "customer_name"
    t.string "description"
    t.datetime "failed_at"
    t.string "failure_reason"
    t.string "idempotency_key"
    t.jsonb "payment_details", default: {}, null: false
    t.string "payment_method", null: false
    t.integer "risk_score", default: 0
    t.string "status", default: "pending", null: false
    t.datetime "updated_at", null: false
    t.index ["customer_email"], name: "index_payments_on_customer_email"
    t.index ["idempotency_key"], name: "index_payments_on_idempotency_key", unique: true, where: "(idempotency_key IS NOT NULL)"
    t.index ["payment_details"], name: "index_payments_on_payment_details", using: :gin
    t.index ["status"], name: "index_payments_on_status"
  end

  create_table "webhook_deliveries", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.integer "attempt_number", default: 1, null: false
    t.datetime "created_at", null: false
    t.string "endpoint_url", null: false
    t.text "error_message"
    t.string "event_type", null: false
    t.datetime "next_retry_at"
    t.uuid "payment_id", null: false
    t.text "response_body"
    t.integer "response_status"
    t.string "status", default: "pending", null: false
    t.datetime "updated_at", null: false
    t.index ["next_retry_at"], name: "index_webhook_deliveries_on_next_retry_at"
    t.index ["payment_id", "event_type"], name: "index_webhook_deliveries_on_payment_id_and_event_type"
    t.index ["payment_id"], name: "index_webhook_deliveries_on_payment_id"
    t.index ["status"], name: "index_webhook_deliveries_on_status"
  end

  add_foreign_key "payment_attempts", "payments"
  add_foreign_key "webhook_deliveries", "payments"
end
