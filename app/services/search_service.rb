class SearchService
  # How far back message search looks. Unlimited by default: a hidden cutoff makes
  # search quietly incomplete, which reads as "search is broken" rather than
  # "search is bounded". Set MESSAGE_SEARCH_WINDOW_MONTHS to bound it if the
  # messages table grows enough for the scan cost to matter.
  def self.message_search_window
    months = ENV.fetch('MESSAGE_SEARCH_WINDOW_MONTHS', '0').to_i
    months.positive? ? months.months : nil
  end

  COMPANY_NAME_CONDITIONS = <<~SQL.squish
    contacts.company_id IN (SELECT companies.id FROM companies WHERE companies.name ILIKE :search)
    OR %<table_name>s.inbox_id IN (
      SELECT inboxes.id FROM inboxes
      INNER JOIN managed_companies ON managed_companies.id = inboxes.managed_company_id
      WHERE managed_companies.name ILIKE :search
    )
  SQL

  CONTACT_CONDITIONS = <<~SQL.squish
    contacts.name ILIKE :search OR contacts.email ILIKE :search OR contacts.phone_number ILIKE :search
    OR contacts.identifier ILIKE :search OR contacts.additional_attributes::text ILIKE :search
    OR contacts.custom_attributes::text ILIKE :search
  SQL

  CONVERSATION_CONDITIONS = <<~SQL.squish
    cast(conversations.display_id as text) ILIKE :search
    OR conversations.additional_attributes ->> 'mail_subject' ILIKE :search
    OR conversations.custom_attributes::text ILIKE :search
    OR #{CONTACT_CONDITIONS}
    OR #{format(COMPANY_NAME_CONDITIONS, table_name: 'conversations')}
    OR conversations.id IN (
      SELECT messages.conversation_id FROM messages
      WHERE messages.account_id = :account_id AND messages.created_at >= :message_since
        AND (messages.content ILIKE :search OR messages.processed_message_content ILIKE :search
             OR messages.content_attributes -> 'email' ->> 'subject' ILIKE :search)
    )
  SQL

  MESSAGE_CONDITIONS = <<~SQL.squish
    messages.content ILIKE :search OR messages.processed_message_content ILIKE :search
    OR messages.content_attributes -> 'email' ->> 'subject' ILIKE :search
    OR conversations.additional_attributes ->> 'mail_subject' ILIKE :search
    OR conversations.custom_attributes::text ILIKE :search
    OR #{CONTACT_CONDITIONS}
    OR #{format(COMPANY_NAME_CONDITIONS, table_name: 'messages')}
  SQL

  pattr_initialize [:current_user!, :current_account!, :params!, :search_type!]

  def account_user
    @account_user ||= current_account.account_users.find_by(user: current_user)
  end

  def perform
    case search_type
    when 'Message'
      { messages: filter_messages }
    when 'Conversation'
      { conversations: filter_conversations }
    when 'Contact'
      { contacts: filter_contacts }
    when 'Article'
      { articles: filter_articles }
    else
      { contacts: filter_contacts, messages: filter_messages, conversations: filter_conversations, articles: filter_articles }
    end
  end

  private

  def accessable_inbox_ids
    @accessable_inbox_ids ||= @current_user.assigned_inboxes.pluck(:id)
  end

  # Single source of truth shared with the conversation list: team-derived inbox
  # access, the conversation-team rule, and Enterprise custom-role restrictions.
  def accessible_conversations
    @accessible_conversations ||= Conversations::PermissionFilterService.new(
      current_account.conversations, @current_user, current_account
    ).perform
  end

  def search_query
    @search_query ||= params[:q].to_s.strip
  end

  # Epoch when unbounded, so the SQL keeps one shape either way.
  def message_since
    @message_since ||= self.class.message_search_window&.ago || Time.zone.at(0)
  end

  def search_conditions
    {
      search: "%#{search_query}%",
      account_id: current_account.id,
      message_since: message_since
    }
  end

  def filter_conversations
    conversations_query = accessible_conversations

    conversations_query = if use_gin_search
                            conversations_query.search_by_term(search_query)
                          else
                            conversations_query.joins('LEFT JOIN contacts ON conversations.contact_id = contacts.id')
                                               .where(CONVERSATION_CONDITIONS, search_conditions)
                          end

    if current_account.feature_enabled?('advanced_search')
      conversations_query = apply_time_filter(conversations_query,
                                              'conversations.last_activity_at')
    end

    conversations_query = conversations_query.order('conversations.created_at DESC') unless use_gin_search

    @conversations = conversations_query.page(params[:page]).per(15)
  end

  def filter_messages
    @messages = if use_gin_search
                  filter_messages_with_gin
                elsif should_run_advanced_search?
                  advanced_search_with_fallback
                else
                  filter_messages_with_like
                end
  end

  def advanced_search_with_fallback
    advanced_search
  rescue Faraday::ConnectionFailed, Searchkick::Error, Elasticsearch::Transport::Transport::Error => e
    Rails.logger.warn("Elasticsearch unavailable, falling back to SQL search: #{e.message}")
    use_gin_search ? filter_messages_with_gin : filter_messages_with_like
  end

  def should_run_advanced_search?
    ChatwootApp.advanced_search_allowed? && current_account.feature_enabled?('advanced_search')
  end

  def advanced_search; end

  def filter_messages_with_gin
    base_query = message_base_query
    base_query = apply_message_filters(base_query)

    return base_query.reorder('created_at DESC').page(params[:page]).per(15) if search_query.blank?

    base_query.search_by_term(search_query)
              .page(params[:page])
              .per(15)
  end

  def filter_messages_with_like
    base_query = message_base_query
    base_query = apply_message_filters(base_query)
    base_query.joins(:conversation)
              .joins('LEFT JOIN contacts ON conversations.contact_id = contacts.id')
              .where(MESSAGE_CONDITIONS, search_conditions)
              .reorder('messages.created_at DESC')
              .page(params[:page])
              .per(15)
  end

  def message_base_query
    query = current_account.messages
    query = query.where('messages.created_at >= ?', message_since) if self.class.message_search_window
    query = query.where(conversation_id: accessible_conversations.select(:id)) unless should_skip_inbox_filtering?
    query
  end

  def apply_message_filters(query)
    return query unless current_account.feature_enabled?('advanced_search')

    query = apply_time_filter(query, 'messages.created_at')
    query = apply_sender_filter(query)
    apply_inbox_id_filter(query)
  end

  def apply_sender_filter(query)
    sender_type, sender_id = parse_from_param(params[:from])
    return query unless sender_type && sender_id

    query.where(sender_type: sender_type, sender_id: sender_id)
  end

  def parse_from_param(from_param)
    return [nil, nil] unless from_param&.match?(/\A(contact|agent):\d+\z/)

    type, id = from_param.split(':')
    sender_type = type == 'agent' ? 'User' : 'Contact'
    [sender_type, id.to_i]
  end

  def apply_inbox_id_filter(query)
    return query if params[:inbox_id].blank?

    inbox_id = params[:inbox_id].to_i
    return query if inbox_id.zero?
    return query unless validate_inbox_access(inbox_id)

    query.where(inbox_id: inbox_id)
  end

  def validate_inbox_access(inbox_id)
    return true if should_skip_inbox_filtering?

    accessable_inbox_ids.include?(inbox_id)
  end

  def should_skip_inbox_filtering?
    account_user.administrator?
  end

  def use_gin_search
    current_account.feature_enabled?('search_with_gin')
  end

  def filter_contacts
    contacts_query = current_account.contacts.accessible_to(@current_user).where(
      "contacts.name ILIKE :search OR contacts.email ILIKE :search OR contacts.phone_number ILIKE :search
       OR contacts.identifier ILIKE :search OR contacts.additional_attributes ->> 'company_name' ILIKE :search
       OR contacts.company_id IN (SELECT companies.id FROM companies WHERE companies.name ILIKE :search)",
      search: "%#{search_query}%"
    )

    contacts_query = apply_time_filter(contacts_query, 'last_activity_at') if current_account.feature_enabled?('advanced_search')

    @contacts = contacts_query.resolved_contacts(
      use_crm_v2: current_account.feature_enabled?('crm_v2')
    ).order_on_last_activity_at('desc').page(params[:page]).per(15)
  end

  def filter_articles
    articles_query = current_account.articles.text_search(search_query)
    articles_query = apply_time_filter(articles_query, 'updated_at') if current_account.feature_enabled?('advanced_search')

    @articles = articles_query.page(params[:page]).per(15)
  end

  def apply_time_filter(query, column_name)
    return query if params[:since].blank? && params[:until].blank?

    query = query.where("#{column_name} >= ?", cap_since_time(params[:since])) if params[:since].present?
    query = query.where("#{column_name} <= ?", cap_until_time(params[:until])) if params[:until].present?
    query
  end

  # Bounded only when an operator configures a window; otherwise the requested
  # range is honoured as asked.
  def cap_since_time(since_param)
    requested_time = Time.zone.at(since_param.to_i)
    window = self.class.message_search_window
    return requested_time if window.nil?

    [requested_time, window.ago].max
  end

  def cap_until_time(until_param)
    max_future = 90.days.from_now
    requested_time = Time.zone.at(until_param.to_i)

    [requested_time, max_future].min
  end
end

SearchService.prepend_mod_with('SearchService')
