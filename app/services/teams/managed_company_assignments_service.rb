class Teams::ManagedCompanyAssignmentsService
  pattr_initialize [:team!, :assignments]

  def perform
    normalized = normalized_assignments
    managed_company_ids = normalized.pluck(:managed_company_id)
    companies = team.account.managed_companies.where(id: managed_company_ids)

    return if invalid_managed_company_ids?(companies, managed_company_ids)

    ActiveRecord::Base.transaction do
      sync_managed_companies(managed_company_ids)
      sync_inboxes(normalized)
    end
  end

  private

  def normalized_assignments
    Array(assignments).filter_map do |assignment|
      data = assignment.respond_to?(:to_h) ? assignment.to_h.symbolize_keys : {}
      managed_company_id = data[:managed_company_id].to_i
      next if managed_company_id <= 0

      {
        managed_company_id: managed_company_id,
        inbox_ids: Array(data[:inbox_ids]).map(&:to_i).select(&:positive?).uniq
      }
    end.uniq { |assignment| assignment[:managed_company_id] }
  end

  def invalid_managed_company_ids?(companies, managed_company_ids)
    return false if companies.size == managed_company_ids.size

    team.errors.add(:managed_company_assignments, 'contains invalid managed company ids')
    raise ActiveRecord::RecordInvalid, team
  end

  def sync_managed_companies(managed_company_ids)
    team.team_managed_companies.where.not(managed_company_id: managed_company_ids).find_each(&:destroy!)
    existing_company_ids = team.team_managed_companies.where(managed_company_id: managed_company_ids).pluck(:managed_company_id)

    (managed_company_ids - existing_company_ids).each do |managed_company_id|
      team.team_managed_companies.create!(account_id: team.account_id, managed_company_id: managed_company_id)
    end
  end

  def sync_inboxes(normalized)
    desired_inbox_ids = normalized.flat_map { |assignment| valid_inbox_ids_for_assignment(assignment) }.uniq
    scoped_inboxes = team.team_inboxes.joins(:inbox).where(inboxes: { managed_company_id: normalized.pluck(:managed_company_id) })

    scoped_inboxes.where.not(inbox_id: desired_inbox_ids).find_each(&:destroy!)
    existing_inbox_ids = scoped_inboxes.where(inbox_id: desired_inbox_ids).pluck(:inbox_id)

    (desired_inbox_ids - existing_inbox_ids).each do |inbox_id|
      team.team_inboxes.create!(account_id: team.account_id, inbox_id: inbox_id)
    end
  end

  def valid_inbox_ids_for_assignment(assignment)
    inbox_ids = team.account.inboxes.where(id: assignment[:inbox_ids], managed_company_id: assignment[:managed_company_id]).pluck(:id)
    return inbox_ids if inbox_ids.size == assignment[:inbox_ids].size

    team.errors.add(:managed_company_assignments, "contains invalid inbox ids for managed company #{assignment[:managed_company_id]}")
    raise ActiveRecord::RecordInvalid, team
  end
end
