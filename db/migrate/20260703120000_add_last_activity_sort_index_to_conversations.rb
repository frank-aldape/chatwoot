class AddLastActivitySortIndexToConversations < ActiveRecord::Migration[7.1]
  disable_ddl_transaction!

  def change
    # Covers "list conversations for this inbox, filtered by status, ordered
    # by last_activity_at" without a separate in-memory sort step once
    # conversations grows into millions of rows per account.
    add_index :conversations, [:account_id, :inbox_id, :status, :last_activity_at],
              name: 'conv_acid_inbid_stat_lastact_idx',
              algorithm: :concurrently
  end
end
