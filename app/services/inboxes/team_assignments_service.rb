class Inboxes::TeamAssignmentsService
  pattr_initialize [:inbox!, :team_ids]

  def perform
    team_ids_to_assign = normalized_team_ids
    teams = inbox.account.teams.where(id: team_ids_to_assign)

    return if invalid_team_ids?(teams, team_ids_to_assign)

    ActiveRecord::Base.transaction do
      inbox.team_inboxes.where.not(team_id: team_ids_to_assign).find_each(&:destroy!)
      existing_team_ids = inbox.team_inboxes.where(team_id: team_ids_to_assign).pluck(:team_id)

      (team_ids_to_assign - existing_team_ids).each do |team_id|
        inbox.team_inboxes.create!(account_id: inbox.account_id, team_id: team_id)
      end
    end
  end

  private

  def normalized_team_ids
    Array(team_ids).map(&:to_i).select(&:positive?).uniq
  end

  def invalid_team_ids?(teams, team_ids_to_assign)
    return false if teams.size == team_ids_to_assign.size

    inbox.errors.add(:team_ids, 'contains invalid team ids')
    raise ActiveRecord::RecordInvalid, inbox
  end
end
