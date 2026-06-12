class CreateTeamManagedCompanyChannelRules < ActiveRecord::Migration[7.1]
  def change
    create_table :team_managed_company_channel_rules do |t|
      t.references :account, null: false, foreign_key: true, index: { name: 'idx_team_company_channel_rules_account_id' }
      t.references :team, null: false, foreign_key: true, index: { name: 'idx_team_company_channel_rules_team_id' }
      t.references :managed_company, null: false, foreign_key: true, index: { name: 'idx_team_company_channel_rules_company_id' }
      t.string :channel_key, null: false

      t.timestamps
    end

    add_index :team_managed_company_channel_rules,
              [:team_id, :managed_company_id, :channel_key],
              unique: true,
              name: 'idx_team_company_channel_rules_unique'
    add_index :team_managed_company_channel_rules,
              [:account_id, :managed_company_id, :channel_key],
              name: 'idx_team_company_channel_rules_lookup'
  end
end
