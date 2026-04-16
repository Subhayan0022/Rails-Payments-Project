class CreatePayments < ActiveRecord::Migration[8.1]
  def change
    create_table :payments, id: :uuid do |t|
      t.string :status,  null: false, default: "pending"
      t.string :payment_method, null: false
      t.string :amount,   null: false
      t.string :currency,  null: false, default: "USD"
      t.string :customer_email,  null: false
      t.string :customer_name
      t.string :description
      t.jsonb :payment_details, null: false, default: {}
      t.integer :risk_score, default: 0
      t.string :idempotency_key
      t.string :failure_reason
      t.datetime :authorized_at
      t.datetime :captured_at
      t.datetime :failed_at

      t.timestamps
    end

    add_index :payments, :status
    add_index :payments, :customer_email
    add_index :payments, :idempotency_key, unique: true, where: "idempotency_key IS NOT NULL"
    add_index :payments, :payment_details, using: :gin
  end
end