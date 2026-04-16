class CreateIdempotencyKeys < ActiveRecord::Migration[8.1]
  def change
    create_table :idempotency_keys, id: :uuid do |t|
      t.string :key, null: false
      t.string :request_path, null: false
      t.jsonb :response_body, null: false, default: '{}'
      t.integer :response_status, null: false
      t.string :payment_id
      t.datetime :expires_at, null: false

      t.timestamps
    end

    add_index :idempotency_keys, :key, unique: true
    add_index :idempotency_keys, :expires_at
  end
end