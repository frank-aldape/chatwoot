class ManagedCompanyPolicy < ApplicationPolicy
  # Read-only for any agent in the account so they can look up which
  # authorized_domain belongs to a company without needing admin rights.
  def index?
    true
  end

  def show?
    true
  end

  def create?
    @account_user.administrator?
  end

  def update?
    @account_user.administrator?
  end

  def destroy?
    @account_user.administrator?
  end
end
