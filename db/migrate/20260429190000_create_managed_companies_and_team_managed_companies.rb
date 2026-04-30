class CreateManagedCompaniesAndTeamManagedCompanies < ActiveRecord::Migration[7.1]
  def change
    create_table :managed_companies do |t|
      t.references :account, null: false, foreign_key: true
      t.string :name, null: false
      t.string :authorized_domain, null: false
      t.integer :status, null: false, default: 0
      t.integer :dns_status, null: false, default: 0
      t.boolean :spf_valid, null: false, default: false
      t.boolean :dkim_valid, null: false, default: false
      t.datetime :last_dns_check_at

      t.timestamps
    end

    add_index :managed_companies, [:account_id, :name], unique: true
    add_index :managed_companies, [:account_id, :authorized_domain], unique: true

    create_table :team_managed_companies do |t|
      t.references :account, null: false, foreign_key: true
      t.references :team, null: false, foreign_key: true
      t.references :managed_company, null: false, foreign_key: true

      t.timestamps
    end

    add_index :team_managed_companies, [:team_id, :managed_company_id], unique: true

    add_reference :inboxes, :managed_company, foreign_key: true
  end
end
