class ContactPolicy < ApplicationPolicy
  def index?
    true
  end

  def active?
    true
  end

  def import?
    @account_user.administrator?
  end

  def export?
    @account_user.administrator?
  end

  def search?
    true
  end

  def filter?
    true
  end

  def update?
    contact_accessible?
  end

  def contactable_inboxes?
    contact_accessible?
  end

  def destroy_custom_attributes?
    contact_accessible?
  end

  def show?
    contact_accessible?
  end

  def create?
    true
  end

  def avatar?
    contact_accessible?
  end

  def destroy?
    @account_user.administrator?
  end

  private

  # Record-level guard: non-admin agents can only act on contacts reachable
  # through their assigned inboxes. List endpoints (index/search/filter/active)
  # stay open here because their controllers already scope the query with
  # Contact.accessible_to. When Pundit authorizes the Contact class (via
  # check_authorization) there is no record to inspect, so we allow and rely
  # on that controller scoping.
  def contact_accessible?
    return true if @account_user.administrator?
    return true unless record.is_a?(Contact)

    record.contact_inboxes.exists?(inbox_id: user.assigned_inboxes.select(:id))
  end
end
