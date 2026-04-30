# frozen_string_literal: true

class RemoveDomainValidationFieldsFromManagedCompanies < ActiveRecord::Migration[7.1]
  def change
    remove_column :managed_companies, :dns_status, :integer
    remove_column :managed_companies, :spf_valid, :boolean
    remove_column :managed_companies, :dkim_valid, :boolean
    remove_column :managed_companies, :last_dns_check_at, :datetime
  end
end
