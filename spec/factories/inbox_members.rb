# frozen_string_literal: true

# Inbox access is derived from team membership, so this factory also materializes
# the backing team -> inbox -> member chain. The InboxMember row itself is created
# first, and TeamMember's roster sync then adopts it instead of duplicating it.
FactoryBot.define do
  factory :inbox_member do
    user { create(:user, :with_avatar) }
    inbox

    transient do
      # Set to false to create a bare roster row with no team behind it.
      with_team_access { true }
    end

    after(:create) do |inbox_member, evaluator|
      next unless evaluator.with_team_access

      inbox = inbox_member.inbox
      account = inbox.account
      # Administrators are deliberately kept out of the roster by the access
      # service, so linking a team would delete the row we just created.
      next if inbox_member.user.account_users.find_by(account_id: account.id)&.administrator?

      team = create(:team, account: account)
      if inbox.managed_company_id.present?
        TeamManagedCompany.find_or_create_by!(
          account_id: account.id, team_id: team.id, managed_company_id: inbox.managed_company_id
        )
      end
      TeamInbox.find_or_create_by!(account_id: account.id, team_id: team.id, inbox_id: inbox.id)
      TeamMember.find_or_create_by!(team_id: team.id, user_id: inbox_member.user_id)
    end
  end
end
