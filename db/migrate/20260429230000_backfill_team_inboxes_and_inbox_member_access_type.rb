class BackfillTeamInboxesAndInboxMemberAccessType < ActiveRecord::Migration[7.1]
  def change
    unless table_exists?(:team_inboxes)
      create_table :team_inboxes do |t|
        t.references :team, null: false, foreign_key: true
        t.references :inbox, null: false, foreign_key: true, type: :integer
        t.references :account, null: false, foreign_key: true, type: :integer

        t.timestamps
      end
    end

    add_index :team_inboxes, [:team_id, :inbox_id], unique: true unless index_exists?(:team_inboxes, [:team_id, :inbox_id], unique: true)
    add_index :team_inboxes, [:account_id, :inbox_id] unless index_exists?(:team_inboxes, [:account_id, :inbox_id])
    add_index :team_inboxes, [:account_id, :team_id] unless index_exists?(:team_inboxes, [:account_id, :team_id])

    add_column :inbox_members, :access_type, :string, null: false, default: 'manual' unless column_exists?(:inbox_members, :access_type)
  end
end
