class AddUserIdIndexToInboxMembers < ActiveRecord::Migration[7.1]
  disable_ddl_transaction!

  def change
    add_index :inbox_members, :user_id, name: 'index_inbox_members_on_user_id', algorithm: :concurrently
  end
end
