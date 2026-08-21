# Read-only: inbox membership is derived from teams. To change who works an inbox,
# link the inbox to a team (Settings > Teams) instead.
class Api::V1::Accounts::InboxMembersController < Api::V1::Accounts::BaseController
  before_action :fetch_inbox

  def show
    authorize @inbox, :show?
    @agents = Current.account.users.where(id: @inbox.inbox_members.select(:user_id))
  end

  private

  def fetch_inbox
    @inbox = Current.account.inboxes.find(params[:inbox_id])
  end
end
