class Teams::ApplyManagedCompanyChannelRulesService
  pattr_initialize [:inbox!]

  def perform
    return if inbox.managed_company_id.blank?

    channel_key = TeamManagedCompanyChannelRule.channel_key_for_inbox(inbox)
    return if channel_key.blank?

    rules.find_each do |rule|
      TeamManagedCompany.find_or_create_by!(
        account_id: inbox.account_id,
        team_id: rule.team_id,
        managed_company_id: inbox.managed_company_id
      )
      TeamInbox.find_or_create_by!(
        account_id: inbox.account_id,
        team_id: rule.team_id,
        inbox_id: inbox.id
      )
    end
  end

  private

  def rules
    TeamManagedCompanyChannelRule.where(
      account_id: inbox.account_id,
      managed_company_id: inbox.managed_company_id,
      channel_key: TeamManagedCompanyChannelRule.channel_key_for_inbox(inbox)
    )
  end
end
