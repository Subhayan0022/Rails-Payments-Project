class CreateMerchantsAndApiKeys < ActiveRecord::Migration[8.1]
  def change
    create_table :merchants, id: :uuid do |t|
      t.string :name, null: false
      t.string :email, null: false
      t.boolean :active, null: false, default: true

      t.timestamps
    end

    add_index :merchants, :email, unique: true

    create_table :api_keys, id: :uuid do |t|
      t.references :merchant, null: false, foreign_key: true, type: :uuid
      t.string :name
      t.string :key_hash, null: false
      t.string :key_prefix, null: false
      t.string :last4, null: false
      t.datetime :last_used_at
      t.datetime :revoked_at

      t.timestamps
    end

    add_index :api_keys, :key_hash, unique: true
    add_index :api_keys, :key_prefix
  end
end
