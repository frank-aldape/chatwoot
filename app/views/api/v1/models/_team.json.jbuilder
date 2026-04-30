json.id resource.id
json.name resource.name
json.description resource.description
json.allow_auto_assign resource.allow_auto_assign
json.account_id resource.account_id
json.managed_company_ids resource.managed_company_ids
json.managed_company_assignments resource.managed_companies.map { |managed_company|
  {
    managed_company_id: managed_company.id,
    inbox_ids: resource.team_inboxes.joins(:inbox).where(inboxes: { managed_company_id: managed_company.id }).pluck(:inbox_id)
  }
}
json.is_member Current.user.teams.include?(resource)
