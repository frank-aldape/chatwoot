class CreateInboundWebhookEvents < ActiveRecord::Migration[7.1]
  def change
    create_table :inbound_webhook_events do |t|
      t.references :account, foreign_key: true
      t.references :inbox, foreign_key: true
      t.string :source, null: false
      t.string :event_type, null: false
      t.string :external_id
      t.string :event_key, null: false
      t.jsonb :payload, null: false, default: {}
      t.integer :status, null: false, default: 0
      t.text :error_message
      t.datetime :processed_at
      t.timestamps
    end

    add_index :inbound_webhook_events, :event_key, unique: true
    add_index :inbound_webhook_events, [:source, :external_id]
    add_index :inbound_webhook_events, [:account_id, :status, :created_at], name: 'idx_inbound_webhook_events_account_status'
  end
end
