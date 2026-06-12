class Teams::ManagedCompanyAssignmentsService
  pattr_initialize [:team!, :assignments]

  def perform
    normalized = normalized_assignments
    managed_company_ids = normalized.pluck(:managed_company_id)
    companies = team.account.managed_companies.where(id: managed_company_ids)

    return if invalid_managed_company_ids?(companies, managed_company_ids)

    ActiveRecord::Base.transaction do
      sync_managed_companies(managed_company_ids)
      sync_channel_rules(normalized)
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
        inbox_ids: Array(data[:inbox_ids]).map(&:to_i).select(&:positive?).uniq,
        channel_keys: normalized_channel_keys(data[:channel_keys])
      }
    end.uniq { |assignment| assignment[:managed_company_id] }
  end

  def normalized_channel_keys(channel_keys)
    Array(channel_keys)
      .map(&:to_s)
      .select { |channel_key| TeamManagedCompanyChannelRule::CHANNEL_KEYS.include?(channel_key) }
      .uniq
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
    desired_inbox_ids = normalized.flat_map { |assignment| desired_inbox_ids_for_assignment(assignment) }.uniq
    scoped_inboxes = team.team_inboxes
                         .joins(:inbox)
                         .where(inboxes: { managed_company_id: normalized.pluck(:managed_company_id) })

    scoped_inboxes.where.not(inbox_id: desired_inbox_ids).find_each(&:destroy!)
    existing_inbox_ids = scoped_inboxes.where(inbox_id: desired_inbox_ids).pluck(:inbox_id)

    (desired_inbox_ids - existing_inbox_ids).each do |inbox_id|
      team.team_inboxes.create!(account_id: team.account_id, inbox_id: inbox_id)
    end
  end

  def sync_channel_rules(normalized)
    managed_company_ids = normalized.pluck(:managed_company_id)
    desired_rules = normalized.flat_map do |assignment|
      assignment[:channel_keys].map { |channel_key| [assignment[:managed_company_id], channel_key] }
    end
    team.team_managed_company_channel_rules.where.not(managed_company_id: managed_company_ids).find_each(&:destroy!)
    scoped_rules = team.team_managed_company_channel_rules.where(managed_company_id: managed_company_ids)

    scoped_rules.find_each do |rule|
      rule.destroy! unless desired_rules.include?([rule.managed_company_id, rule.channel_key])
    end

    desired_rules.each do |managed_company_id, channel_key|
      team.team_managed_company_channel_rules.find_or_create_by!(
        account_id: team.account_id,
        managed_company_id: managed_company_id,
        channel_key: channel_key
      )
    end
  end

  def desired_inbox_ids_for_assignment(assignment)
    explicit_inbox_ids = valid_inbox_ids_for_assignment(assignment)
    rule_inbox_ids = inbox_ids_matching_channel_rules(assignment)

    (explicit_inbox_ids + rule_inbox_ids).uniq
  end

  def inbox_ids_matching_channel_rules(assignment)
    return [] if assignment[:channel_keys].blank?

    team.account.inboxes
        .where(managed_company_id: assignment[:managed_company_id])
        .select do |inbox|
          assignment[:channel_keys].include?(TeamManagedCompanyChannelRule.channel_key_for_inbox(inbox))
        end
        .map(&:id)
  end

  def valid_inbox_ids_for_assignment(assignment)
    inbox_ids = team.account.inboxes
                    .where(id: assignment[:inbox_ids], managed_company_id: assignment[:managed_company_id])
                    .pluck(:id)
    return inbox_ids if inbox_ids.size == assignment[:inbox_ids].size

    team.errors.add(
      :managed_company_assignments,
      "contains invalid inbox ids for managed company #{assignment[:managed_company_id]}"
    )
    raise ActiveRecord::RecordInvalid, team
  end
end
