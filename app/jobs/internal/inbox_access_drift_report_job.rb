# Weekly read-only check of the team-derived inbox access model.
# Surfaces the two gaps `rake inbox_access:report` looks for, without anyone
# having to remember to run it: agents holding roster rows no team backs, and
# inboxes no team can see.
class Internal::InboxAccessDriftReportJob < ApplicationJob
  queue_as :housekeeping

  def perform
    findings = Account.find_each.filter_map { |account| account_drift(account) }
    return if findings.empty?

    Rails.logger.warn("[inbox_access_drift] #{findings.to_json}")
    return unless Internal::AlertWebhook.configured?

    Internal::AlertWebhook.post(
      text: "#{ENV.fetch('ALERT_INSTANCE_NAME', 'Chatwoot production')} inbox access drift",
      status: 'warning',
      generated_at: Time.current.iso8601,
      check: 'inbox_access_drift',
      accounts: findings
    )
  end

  private

  def account_drift(account)
    agents = agents_without_team_backing(account)
    orphans = orphan_inboxes(account)
    return if agents.empty? && orphans.empty?

    {
      account_id: account.id,
      account_name: account.name,
      agents_without_team_backing: agents,
      inboxes_without_team: orphans
    }
  end

  # Roster rows only drive auto-assignment; visibility comes from teams. A row
  # with no team behind it means the agent is in the round-robin for an inbox
  # they cannot open.
  def agents_without_team_backing(account)
    account.account_users.where(role: :agent).includes(:user).filter_map do |account_user|
      roster = InboxMember.joins(:inbox)
                          .where(inboxes: { account_id: account.id }, user_id: account_user.user_id)
                          .distinct.pluck(:inbox_id)
      orphaned = roster - team_inbox_ids(account, account_user.user_id)
      next if orphaned.empty?

      { email: account_user.user.email, inbox_ids: orphaned }
    end
  end

  def orphan_inboxes(account)
    account.inboxes
           .where.not(id: TeamInbox.where(account_id: account.id).select(:inbox_id))
           .pluck(:id, :name)
           .map { |id, name| { id: id, name: name } }
  end

  def team_inbox_ids(account, user_id)
    TeamInbox.joins(team: :team_members)
             .where(account_id: account.id, team_members: { user_id: user_id })
             .distinct.pluck(:inbox_id)
  end
end
