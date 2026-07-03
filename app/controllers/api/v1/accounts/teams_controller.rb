class Api::V1::Accounts::TeamsController < Api::V1::Accounts::BaseController
  before_action :fetch_team, only: [:show, :update, :destroy]
  before_action :check_authorization

  def index
    @teams = Current.account.teams.includes(:managed_companies, { team_inboxes: :inbox }, :team_managed_company_channel_rules)
  end

  def show; end

  def create
    @team = Current.account.teams.new(team_record_params)
    @team.save!
    update_managed_company_assignments if managed_company_assignments_present?
  end

  def update
    @team.update!(team_record_params)
    update_managed_company_assignments if managed_company_assignments_present?
  end

  def destroy
    @team.destroy!
    head :ok
  end

  private

  def fetch_team
    @team = Current.account.teams.find(params[:id])
  end

  def team_params
    raw_team_params.permit(
      :name,
      :description,
      :allow_auto_assign,
      managed_company_assignments: [:managed_company_id, { inbox_ids: [], channel_keys: [] }]
    )
  end

  def team_record_params
    team_params.except(:managed_company_assignments)
  end

  def raw_team_params
    if params[:team].present?
      if params[:managed_company_assignments].present? && params[:team][:managed_company_assignments].blank?
        params[:team] = params[:team].merge(managed_company_assignments: params[:managed_company_assignments])
      end
      params[:team]
    else
      params
    end
  end

  def managed_company_assignments_present?
    team_params.key?(:managed_company_assignments)
  end

  def update_managed_company_assignments
    ::Teams::ManagedCompanyAssignmentsService.new(
      team: @team,
      assignments: team_params[:managed_company_assignments]
    ).perform
  end
end
