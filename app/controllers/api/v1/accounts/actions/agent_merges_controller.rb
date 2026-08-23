class Api::V1::Accounts::Actions::AgentMergesController < Api::V1::Accounts::BaseController
  before_action :check_authorization
  before_action :set_agents

  def create
    @agent = AgentMergeAction.new(
      account: Current.account,
      base_agent: @base_agent,
      mergee_agent: @mergee_agent,
      prevailing_email: prevailing_email
    ).perform
  rescue StandardError => e
    render_could_not_create_error(e.message)
  end

  private

  def check_authorization
    authorize(User)
  end

  def set_agents
    @base_agent = agents.find(params[:base_agent_id])
    @mergee_agent = agents.find(params[:mergee_agent_id])
    return unless @mergee_agent.id == Current.user.id

    render_could_not_create_error('You cannot merge your own account into another agent')
  end

  def prevailing_email
    params[:email].presence&.downcase || @base_agent.email
  end

  def agents
    @agents ||= Current.account.users
  end
end
