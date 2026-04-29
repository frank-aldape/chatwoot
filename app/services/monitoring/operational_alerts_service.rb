class Monitoring::OperationalAlertsService
  WEBHOOK_BACKLOG_WARNING = 100
  WEBHOOK_BACKLOG_CRITICAL = 500
  WEBHOOK_OLDEST_BACKLOG_WARNING_SECONDS = 120
  WEBHOOK_OLDEST_BACKLOG_CRITICAL_SECONDS = 300
  WEBHOOK_FAILURE_RATE_WARNING = 0.03
  WEBHOOK_FAILURE_RATE_CRITICAL = 0.05
  WEBHOOK_MEDIA_QUEUE_WARNING = 50
  WEBHOOK_MEDIA_QUEUE_CRITICAL = 200
  PARTITION_REVIEW_TOTAL_MESSAGES = 50_000_000
  PARTITION_REVIEW_TOP_ACCOUNT_MESSAGES = 5_000_000
  PARTITION_REVIEW_MESSAGES_LAST_30_DAYS = 5_000_000

  def initialize(metrics)
    @metrics = metrics
  end

  def perform
    {}.tap do |alerts|
      add_webhook_alerts(alerts)
      add_partitioning_alerts(alerts)
    end
  end

  private

  attr_reader :metrics

  def add_webhook_alerts(alerts)
    backlog = metric_value('Inbound webhook backlog')
    oldest_backlog_seconds = age_metric_in_seconds('Inbound webhook oldest backlog age')
    received_24h = metric_value('Inbound webhook received (24h)')
    failed_24h = metric_value('Inbound webhook failed (24h)')
    webhooks_queue = metric_value('Sidekiq queue webhooks size')
    media_queue = metric_value('Sidekiq queue media size')
    failure_rate = received_24h.positive? ? failed_24h.to_f / received_24h : 0

    alerts['Alert webhook backlog'] = level_for_threshold(backlog, WEBHOOK_BACKLOG_WARNING, WEBHOOK_BACKLOG_CRITICAL)
    alerts['Alert webhook backlog oldest age'] =
      level_for_threshold(oldest_backlog_seconds, WEBHOOK_OLDEST_BACKLOG_WARNING_SECONDS, WEBHOOK_OLDEST_BACKLOG_CRITICAL_SECONDS)
    alerts['Alert webhook failure rate (24h)'] =
      level_for_threshold(failure_rate, WEBHOOK_FAILURE_RATE_WARNING, WEBHOOK_FAILURE_RATE_CRITICAL)
    alerts['Alert queue webhooks'] = level_for_threshold(webhooks_queue, WEBHOOK_BACKLOG_WARNING, WEBHOOK_BACKLOG_CRITICAL)
    alerts['Alert queue media'] = level_for_threshold(media_queue, WEBHOOK_MEDIA_QUEUE_WARNING, WEBHOOK_MEDIA_QUEUE_CRITICAL)
    alerts['Webhook failure rate (24h)'] = format('%.2f%%', failure_rate * 100)
  end

  def add_partitioning_alerts(alerts)
    total_messages = metric_value('Messages total')
    messages_last_30_days = metric_value('Messages last 30 days')
    top_account_messages = top_account_messages

    total_messages_flag = total_messages >= PARTITION_REVIEW_TOTAL_MESSAGES
    top_account_flag = top_account_messages >= PARTITION_REVIEW_TOP_ACCOUNT_MESSAGES
    monthly_growth_flag = messages_last_30_days >= PARTITION_REVIEW_MESSAGES_LAST_30_DAYS

    alerts['Partition review total messages'] = total_messages_flag ? 'warning' : 'ok'
    alerts['Partition review top account'] = top_account_flag ? 'warning' : 'ok'
    alerts['Partition review monthly growth'] = monthly_growth_flag ? 'warning' : 'ok'
    alerts['Partitioning recommendation'] =
      partitioning_recommendation(total_messages_flag, top_account_flag, monthly_growth_flag)
  end

  def partitioning_recommendation(total_messages_flag, top_account_flag, monthly_growth_flag)
    flags = [total_messages_flag, top_account_flag, monthly_growth_flag].count(true)
    return 'evaluate_now' if flags >= 2
    return 'evaluate_soon' if flags == 1

    'not_needed_yet'
  end

  def metric_value(key)
    value = metrics[key]
    return 0 if value.blank? || value == 'none' || value == 'unavailable'
    return value if value.is_a?(Numeric)
    return value.to_s.delete_suffix('s').to_i if value.is_a?(String) && value.match?(/\A\d+s\z/)

    value.to_s[/\d+/].to_i
  end

  def age_metric_in_seconds(key)
    value = metrics[key]
    return 0 if value.blank? || value == 'none'

    value.to_s.delete_suffix('s').to_i
  end

  def top_account_messages
    value = metrics['Top account by messages'].to_s
    match = value.match(/count=(\d+)/)
    match ? match[1].to_i : 0
  end

  def level_for_threshold(value, warning_threshold, critical_threshold)
    return 'critical' if value >= critical_threshold
    return 'warning' if value >= warning_threshold

    'ok'
  end
end
