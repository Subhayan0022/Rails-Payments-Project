class ScopePaymentsToMerchants < ActiveRecord::Migration[8.1]
  def change
    add_reference :payments, :merchant, type: :uuid, foreign_key: true, null: false
    add_reference :idempotency_keys, :merchant, type: :uuid, foreign_key: true, null: false

    remove_index :idempotency_keys, :key
    add_index :idempotency_keys, [:merchant_id, :key], unique: true

    remove_index :payments, :idempotency_key, where: "(idempotency_key IS NOT NULL)"
    add_index :payments, [:merchant_id, :idempotency_key],
              unique: true,
              where: "(idempotency_key IS NOT NULL)",
              name: "index_payments_on_merchant_and_idempotency_key"
  end
end
