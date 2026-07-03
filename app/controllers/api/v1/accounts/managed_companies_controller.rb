class Api::V1::Accounts::ManagedCompaniesController < Api::V1::Accounts::BaseController
  before_action :fetch_managed_company, only: [:show, :update, :destroy]
  before_action :check_authorization

  def index
    @managed_companies = Current.account.managed_companies.ordered_by_name.includes(:inboxes, :teams)
  end

  def show; end

  def create
    @managed_company = Current.account.managed_companies.create!(managed_company_params)
  end

  def update
    @managed_company.update!(managed_company_params)
  end

  def destroy
    @managed_company.destroy!
    head :ok
  end

  private

  def fetch_managed_company
    @managed_company = Current.account.managed_companies.find(params[:id])
  end

  def managed_company_params
    params.require(:managed_company).permit(:name, :authorized_domain, :status)
  end
end
