# Sets the teams a user belongs to within one account, in a single call.
#
# Teams are the permission preset, so this is where an administrator grants or
# revokes what an agent can see. TeamMember callbacks keep the inbox roster in
# step, so nothing else needs touching here.
class Teams::SyncMemberTeamsService
  pattr_initialize [:account!, :user!, :team_ids!]

  def perform
    desired = account.teams.where(id: team_ids).pluck(:id)
    current = TeamMember.joins(:team).where(teams: { account_id: account.id }, user_id: user.id).pluck(:team_id)

    (desired - current).each { |team_id| TeamMember.create!(team_id: team_id, user_id: user.id) }
    TeamMember.where(team_id: current - desired, user_id: user.id).destroy_all
  end
end
