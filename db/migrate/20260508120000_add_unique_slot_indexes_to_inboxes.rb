class AddUniqueSlotIndexesToInboxes < ActiveRecord::Migration[7.1]
  # Adds a denormalized `integration_slot` column to inboxes so the uniqueness
  # constraint per managed company can be enforced at the database level for
  # ALL slot types, including those (LinkedIn, Facebook/Instagram) whose
  # discriminating data lives in separate channel tables.
  #
  # The column is kept in sync via Inbox#sync_integration_slot (before_save).
  def change
    add_column :inboxes, :integration_slot, :string

    add_index :inboxes, %i[managed_company_id integration_slot],
              unique: true,
              where: 'managed_company_id IS NOT NULL AND integration_slot IS NOT NULL',
              name: 'idx_unique_integration_slot_per_managed_company'
  end
end
