# Recomputes a user's inbox_members rows for one account from their team
# membership. Visibility is derived live from teams, so this only keeps the
# assignment/round-robin roster in sync.
class Inboxes::SyncMemberRosterJob < ApplicationJob
  queue_as :low

  def perform(account_id, user_id)
    account = Account.find_by(id: account_id)
    user = User.find_by(id: user_id)
    return if account.blank? || user.blank?

    account.inboxes.find_each do |inbox|
      ::InboxMembers::AccessService.new(inbox: inbox, user: user).sync!
    end
    account.update_cache_key('inbox')
  end
end
