class InboxMembers::AccessService
  pattr_initialize [:inbox!, :user!]

  def grant_manual_access!
    return if account_administrator?

    if inbox_member
      inbox_member.update!(access_type: 'manual') if inbox_member.team_access?
    else
      inbox.inbox_members.create!(user: user, access_type: 'manual')
    end
  end

  def revoke_manual_access!
    return if account_administrator?
    return unless inbox_member

    if team_access_available?
      inbox_member.update!(access_type: 'team') if inbox_member.manual_access?
    else
      inbox_member.destroy!
    end
  end

  def grant_team_access!
    return if account_administrator?
    return if inbox_member&.manual_access? || inbox_member&.team_access?

    inbox.inbox_members.create!(user: user, access_type: 'team')
  end

  def revoke_team_access!
    return if account_administrator?
    return unless inbox_member
    return if inbox_member.manual_access? || team_access_available?

    inbox_member.destroy!
  end

  private

  def inbox_member
    @inbox_member ||= inbox.inbox_members.find_by(user_id: user.id)
  end

  def team_access_available?
    TeamInbox.joins(team: :team_members)
             .where(account_id: inbox.account_id, inbox_id: inbox.id, team_members: { user_id: user.id })
             .exists?
  end

  def account_administrator?
    @account_administrator ||= user.account_users.find_by(account_id: inbox.account_id)&.administrator?
  end
end
