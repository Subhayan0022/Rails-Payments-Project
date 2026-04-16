class CreateWebhookDeliveries < ActiveRecord::Migration[8.1]
  def change
    create_table :webhook_deliveries, id: :uuid do |t|
      t.references :payment, null: false, foreign_key: true, type: :uuid
      t.string :event_type, null: false
      t.string :endpoint_url, null: false # the merchant URL
      t.integer :response_status
      t.text :response_body
      t.integer :attempt_number, null: false, default: 1
      t.string :status, null: false, default: 'pending'
      t.datetime :next_retry_at
      t.text :error_message

      t.timestamps
    end

    add_index :webhook_deliveries, [:payment_id, :event_type]
    add_index :webhook_deliveries, :status
    add_index :webhook_deliveries, :next_retry_at # use exponential backoff
  end
end
