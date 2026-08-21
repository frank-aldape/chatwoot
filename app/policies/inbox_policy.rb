class InboxPolicy < ApplicationPolicy
  class Scope
    attr_reader :user_context, :user, :scope, :account, :account_user

    def initialize(user_context, scope)
      @user_context = user_context
      @user = user_context[:user]
      @account = user_context[:account]
      @account_user = user_context[:account_user]
      @scope = scope
    end

    def resolve
      # Narrow the scope we were handed instead of building a fresh relation:
      # returning a new one discarded the controller's eager loading and turned
      # the inbox list into an N+1 over teams, managed_company and channel.
      return scope if account_user&.administrator?

      scope.where(id: user.accessible_inbox_ids_for(account))
    end
  end

  def index?
    true
  end

  def show?
    # FIXME: for agent bots, lets bring this validation to policies as well in future
    return true if @user.is_a?(AgentBot)
    return true if account_user&.administrator?
    return false if account.blank?

    # exists? instead of loading the relation: for an administrator the old
    # `assigned_inboxes.include?` materialized every inbox in the account.
    Current.user.member_of_inbox?(account, record.id)
  end

  def assignable_agents?
    true
  end

  def agent_bot?
    true
  end

  def campaigns?
    @account_user.administrator?
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

  def set_agent_bot?
    @account_user.administrator?
  end

  def avatar?
    @account_user.administrator?
  end

  def sync_templates?
    @account_user.administrator?
  end

  def health?
    @account_user.administrator?
  end
end
