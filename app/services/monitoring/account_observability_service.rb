class Monitoring::AccountObservabilityService
  MONTHLY_GROWTH_WINDOW = 6.months

  def initialize(account)
    @account = account
  end

  def perform
    {
      summary_metrics: summary_metrics,
      inbox_breakdown: inbox_breakdown,
      recent_failed_events: recent_failed_events,
      monthly_growth: monthly_growth
    }
  end

  private

  attr_reader :account

  def summary_metrics
    received_24h = account_events.where(created_at: 24.hours.ago..Time.current).count
    failed_24h = account_events.failed.where(updated_at: 24.hours.ago..Time.current).count
    failure_rate_24h = received_24h.positive? ? (failed_24h.to_f / received_24h) : 0

    {
      'Account ID' => account.id,
      'Account name' => account.name,
      'Messages total' => account.messages.count,
      'Messages last 30 days' => account.messages.where(created_at: 30.days.ago..Time.current).count,
      'Conversations total' => account.conversations.count,
      'Conversations open' => account.conversations.open.count,
      'Conversations pending' => account.conversations.pending.count,
      'Conversations resolved' => account.conversations.resolved.count,
      'Conversations snoozed' => account.conversations.snoozed.count,
      'Contacts total' => account.contacts.count,
      'Inbound webhook events total' => account_events.count,
      'Inbound webhook backlog' => account_events.where(status: %i[received processing]).count,
      'Inbound webhook failed' => account_events.failed.count,
      'Inbound webhook invalid' => account_events.invalid.count,
      'Inbound webhook received (24h)' => received_24h,
      'Inbound webhook failed (24h)' => failed_24h,
      'Inbound webhook failure rate (24h)' => format('%.2f%%', failure_rate_24h * 100),
      'Partitioning recommendation' => partitioning_recommendation
    }
  end

  def inbox_breakdown
    inbox_message_counts = account.messages.group(:inbox_id).count
    inbox_recent_message_counts = account.messages.where(created_at: 30.days.ago..Time.current).group(:inbox_id).count
    inbox_backlog_counts = account_events.where(status: %i[received processing]).group(:inbox_id).count
    inbox_failed_counts = account_events.failed.group(:inbox_id).count

    account.inboxes.map do |inbox|
      {
        id: inbox.id,
        name: inbox.name,
        channel_type: inbox.channel_type,
        messages_total: inbox_message_counts[inbox.id] || 0,
        messages_last_30_days: inbox_recent_message_counts[inbox.id] || 0,
        webhook_backlog: inbox_backlog_counts[inbox.id] || 0,
        webhook_failed: inbox_failed_counts[inbox.id] || 0
      }
    end.sort_by { |row| -row[:messages_total] }
  end

  def recent_failed_events
    account_events.failed.recent_first.limit(25)
  end

  def monthly_growth
    account.messages
           .where(created_at: MONTHLY_GROWTH_WINDOW.ago..Time.current)
           .group("date_trunc('month', created_at)")
           .order(Arel.sql("date_trunc('month', created_at) DESC"))
           .count
           .map do |month, count|
      {
        month: month.strftime('%Y-%m'),
        messages: count
      }
    end
  end

  def partitioning_recommendation
    total_messages = account.messages.count
    monthly_messages = account.messages.where(created_at: 30.days.ago..Time.current).count

    return 'evaluate_now' if total_messages >= 5_000_000 && monthly_messages >= 500_000
    return 'evaluate_soon' if total_messages >= 1_000_000 || monthly_messages >= 250_000

    'not_needed_yet'
  end

  def account_events
    @account_events ||= InboundWebhookEvent.where(account_id: account.id)
  end
end
