class CreatePaymentAttempts < ActiveRecord::Migration[8.1]
  def change
    create_table :payment_attempts, id: :uuid do |t|
      t.references :payment, null: false, foreign_key: true, type: :uuid
      t.string :status, null: false
      t.string :processor_response # response from the payment processor.
      t.jsonb :metadata, default: {}
      t.integer :attempt_number, null: false, default: 1

      t.timestamps
    end

    add_index :payment_attempts, [:payment_id, :attempt_number]
  end
end