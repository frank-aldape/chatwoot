# Links every existing inbox whose mailbox matches one of the team's mailbox
# rules. Additive on purpose: it never unlinks, so a team keeps inboxes that
# were attached by hand or by the managed-company rules.
class Teams::SyncMailboxInboxesService
  pattr_initialize [:team!]

  MATCHING_IDS_SQL = <<~SQL.squish
    SELECT i.id FROM inboxes i
    LEFT JOIN channel_email ce ON i.channel_type = 'Channel::Email' AND ce.id = i.channel_id
    WHERE i.account_id = :account_id
      AND lower(split_part(COALESCE(ce.email, i.email_address), '@', 1)) IN (:mailboxes)
  SQL

  def perform
    return if team.mailboxes.blank?

    already_linked = TeamInbox.where(team_id: team.id).pluck(:inbox_id).to_set

    team.account.inboxes.where(id: matching_inbox_ids).find_each do |inbox|
      next if already_linked.include?(inbox.id)

      link!(inbox)
    end
  end

  private

  def matching_inbox_ids
    ActiveRecord::Base.connection.select_values(
      ActiveRecord::Base.sanitize_sql_array(
        [MATCHING_IDS_SQL, { account_id: team.account_id, mailboxes: team.mailboxes }]
      )
    )
  end

  def link!(inbox)
    company_id = inbox.managed_company_id
    if company_id.present? && !TeamManagedCompany.exists?(team_id: team.id, managed_company_id: company_id)
      TeamManagedCompany.create!(account_id: team.account_id, team_id: team.id, managed_company_id: company_id)
    end

    TeamInbox.create!(account_id: team.account_id, team_id: team.id, inbox_id: inbox.id)
  end
end
