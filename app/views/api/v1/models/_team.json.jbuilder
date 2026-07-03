json.id resource.id
json.name resource.name
json.description resource.description
json.allow_auto_assign resource.allow_auto_assign
json.account_id resource.account_id
json.managed_company_ids resource.managed_company_ids
json.managed_company_assignments resource.managed_companies.map { |managed_company|
  # Filters the preloaded in-memory collections (see TeamsController#index
  # `.includes`) instead of re-querying per managed company, which is what
  # made this N+1 even when the associations were eager loaded.
  team_company_inboxes = resource.team_inboxes
                                 .select { |team_inbox| team_inbox.inbox.managed_company_id == managed_company.id }
                                 .map(&:inbox_id)
  channel_keys = resource.team_managed_company_channel_rules
                         .select { |rule| rule.managed_company_id == managed_company.id }
                         .map(&:channel_key)

  {
    managed_company_id: managed_company.id,
    inbox_ids: team_company_inboxes,
    channel_keys: channel_keys
  }
}
json.is_member Current.user.teams.include?(resource)
