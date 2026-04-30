class TeamManagedCompany < ApplicationRecord
  belongs_to :account
  belongs_to :team
  belongs_to :managed_company

  validates :team_id, uniqueness: { scope: :managed_company_id }
  validate :ensure_account_integrity

  before_validation :sync_account_id
  after_destroy :remove_team_inboxes_for_company

  private

  def sync_account_id
    self.account_id ||= team&.account_id || managed_company&.account_id
  end

  def ensure_account_integrity
    return if account_id.blank? || team.blank? || managed_company.blank?

    errors.add(:account_id, :invalid) if team.account_id != account_id || managed_company.account_id != account_id
  end

  def remove_team_inboxes_for_company
    team.team_inboxes.joins(:inbox)
        .where(inboxes: { managed_company_id: managed_company_id })
        .find_each(&:destroy!)
  end
end
