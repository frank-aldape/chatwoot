# inbox_members is a materialized roster of "who works this inbox". It is fully
# derived from team membership: a row exists if and only if the user belongs to a
# team linked to the inbox. It powers auto-assignment, round-robin and the
# assignable-agents list -- it is never the source of truth for visibility, which
# is derived live from team_inboxes (see User#assigned_inboxes).
class InboxMembers::AccessService
  pattr_initialize [:inbox!, :user!]

  # Recomputes this user's roster entry for this inbox from the current teams.
  # Administrators reach every inbox implicitly and are never queued for
  # round-robin, so they are kept out of the roster entirely.
  def sync!
    return remove_member! if account_administrator?

    team_access_available? ? ensure_member! : remove_member!
  end

  private

  def ensure_member!
    if inbox_member
      inbox_member.update!(access_type: 'team') unless inbox_member.team_access?
    else
      inbox.inbox_members.create!(user: user, access_type: 'team')
    end
  end

  def remove_member!
    inbox_member&.destroy!
  end

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
