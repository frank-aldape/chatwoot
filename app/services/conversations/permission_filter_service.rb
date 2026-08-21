class Conversations::PermissionFilterService
  attr_reader :conversations, :user, :account

  def initialize(conversations, user, account)
    @conversations = conversations
    @user = user
    @account = account
  end

  def perform
    return conversations if user_role == 'administrator'

    accessible_conversations
  end

  private

  # Access comes from teams only. A conversation is visible when its inbox belongs
  # to one of the user's teams, or when the conversation itself is assigned to one
  # of those teams (mirrors ConversationPolicy#team_access? so the list, the search
  # and opening by URL all agree).
  def accessible_conversations
    conversations.where(inbox_id: accessible_inbox_ids)
                 .or(conversations.where(team_id: user_team_ids))
  end

  def accessible_inbox_ids
    user.accessible_inbox_ids_for(account)
  end

  def user_team_ids
    user.team_ids_for(account)
  end

  def account_user
    return @account_user if defined?(@account_user)

    @account_user = AccountUser.find_by(account_id: account.id, user_id: user.id)
  end

  def user_role
    account_user&.role
  end
end

Conversations::PermissionFilterService.prepend_mod_with('Conversations::PermissionFilterService')
