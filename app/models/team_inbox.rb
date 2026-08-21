class TeamInbox < ApplicationRecord
  belongs_to :account
  belongs_to :team
  belongs_to :inbox

  validates :team_id, uniqueness: { scope: :inbox_id }
  validate :ensure_account_integrity

  before_validation :sync_account_id
  after_create :sync_team_members_roster
  after_destroy :sync_team_members_roster

  private

  def sync_account_id
    self.account_id ||= team&.account_id || inbox&.account_id
  end

  def ensure_account_integrity
    return if account_id.blank? || team.blank? || inbox.blank?

    errors.add(:account_id, :invalid) if team.account_id != account_id || inbox.account_id != account_id
    return if inbox.managed_company_id.blank?
    return if team.team_managed_companies.where(managed_company_id: inbox.managed_company_id).exists?

    errors.add(:team_id, 'must be linked to the inbox managed company')
  end

  def sync_team_members_roster
    team.members.find_each do |member|
      InboxMembers::AccessService.new(inbox: inbox, user: member).sync!
    end
    account.update_cache_key('inbox')
  end
end
