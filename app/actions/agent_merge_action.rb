class AgentMergeAction
  pattr_initialize [:account!, :base_agent!, :mergee_agent!, :prevailing_email!]

  # Tables that point at a user with no uniqueness constraint in the way: the
  # mergee's rows are simply repointed at the base agent so the history survives.
  REPOINTS = [
    [Conversation, :assignee_id],
    [CsatSurveyResponse, :assigned_agent_id],
    [CsatSurveyResponse, :review_notes_updated_by_id],
    [Note, :user_id],
    [ReportingEvent, :user_id],
    [Notification, :user_id],
    [CustomFilter, :user_id],
    [DashboardApp, :user_id],
    [Article, :author_id],
    [Macro, :created_by_id],
    [Macro, :updated_by_id],
    [Campaign, :sender_id],
    [AccountUser, :inviter_id]
  ].freeze

  # Tables with a `(scope, user_id)` unique index: rows the base agent already
  # holds for the same scope are dropped before the rest are repointed.
  SCOPED_REPOINTS = [
    [InboxMember, :inbox_id],
    [TeamMember, :team_id],
    [ConversationParticipant, :conversation_id],
    [Mention, :conversation_id]
  ].freeze

  def perform
    ActiveRecord::Base.transaction do
      validate_agents
      repoint_records
      repoint_scoped_records
      repoint_messages
      remove_mergee_agent
      apply_prevailing_email
    end
    @base_agent
  end

  private

  def validate_agents
    raise StandardError, 'An agent cannot be merged into itself' if @base_agent.id == @mergee_agent.id
    raise StandardError, 'Agent does not belong to the account' unless [@base_agent, @mergee_agent].all? { |agent| belongs_to_account?(agent) }
    # The mergee user record is deleted, so it must not carry history in another account.
    raise StandardError, 'The agent being merged belongs to other accounts' if other_account_memberships?
    raise StandardError, 'The prevailing email must belong to one of the two agents' unless prevailing_email_valid?
  end

  def belongs_to_account?(agent)
    agent.account_users.exists?(account_id: @account.id)
  end

  def other_account_memberships?
    @mergee_agent.account_users.where.not(account_id: @account.id).exists?
  end

  def prevailing_email_valid?
    [@base_agent.email, @mergee_agent.email].include?(@prevailing_email)
  end

  # rubocop:disable Rails/SkipsModelValidations
  def repoint_records
    REPOINTS.each do |model, column|
      model.where(column => @mergee_agent.id).update_all(column => @base_agent.id)
    end
  end

  def repoint_scoped_records
    SCOPED_REPOINTS.each do |model, scope_column|
      already_held = model.where(user_id: @base_agent.id).select(scope_column)
      model.where(user_id: @mergee_agent.id, scope_column => already_held).delete_all
      model.where(user_id: @mergee_agent.id).update_all(user_id: @base_agent.id)
    end
  end

  def repoint_messages
    Message.where(sender_type: 'User', sender_id: @mergee_agent.id).update_all(sender_id: @base_agent.id)
  end
  # rubocop:enable Rails/SkipsModelValidations

  def remove_mergee_agent
    # Reload so the associations emptied above are not destroyed from a stale cache.
    @mergee_agent.reload.destroy!
  end

  # Runs last: the mergee row has to be gone before its email can be reused.
  def apply_prevailing_email
    return if @base_agent.email == @prevailing_email

    @base_agent.skip_reconfirmation!
    # uid is the login handle only for password logins; SSO logins key off the provider id.
    @base_agent.uid = @prevailing_email if @base_agent.provider == 'email'
    @base_agent.update!(email: @prevailing_email)
  end
end
