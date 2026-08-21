# Links a newly created inbox to the teams that declare its mailbox.
#
# Access is granted per mailbox (the local-part of the address, domain ignored),
# so an inbox for `ventas@nueva-empresa.com` joins every team whose mailbox rules
# include `ventas`. When no team declares the mailbox nothing is linked, and the
# inbox is reported by `rake inbox_access:recommend` for a human to decide --
# guessing would hand conversations to the wrong people.
class Teams::ApplyMailboxRulesService
  pattr_initialize [:inbox!]

  def perform
    return if mailbox.blank?

    inbox.account.teams.serving_mailbox(mailbox).each { |team| link_to_team!(team) }
  end

  private

  # Mirrors Inbox#channel_email: the channel address wins, the column is the fallback.
  def mailbox
    return @mailbox if defined?(@mailbox)

    address = inbox.channel.try(:email).presence || inbox.email_address
    @mailbox = address.to_s.split('@').first.to_s.strip.downcase
  end

  def link_to_team!(team)
    return if TeamInbox.exists?(team_id: team.id, inbox_id: inbox.id)

    company_id = inbox.managed_company_id
    if company_id.present? && !TeamManagedCompany.exists?(team_id: team.id, managed_company_id: company_id)
      TeamManagedCompany.create!(account_id: inbox.account_id, team_id: team.id, managed_company_id: company_id)
    end

    TeamInbox.create!(account_id: inbox.account_id, team_id: team.id, inbox_id: inbox.id)
  end
end
