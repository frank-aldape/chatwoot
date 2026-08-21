# Runs off the request so saving a team with many mailboxes stays fast.
class Teams::SyncMailboxInboxesJob < ApplicationJob
  queue_as :low

  def perform(team_id)
    team = Team.find_by(id: team_id)
    return if team.blank?

    ::Teams::SyncMailboxInboxesService.new(team: team).perform
  end
end
