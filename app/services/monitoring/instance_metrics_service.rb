class Monitoring::InstanceMetricsService
  WEBHOOK_SOURCES = %w[whatsapp instagram].freeze
  TRACKED_TABLES = %w[messages conversations contacts inbound_webhook_events].freeze

  def perform
    {}.tap do |metrics|
      add_chatwoot_meta(metrics)
      add_postgres_status(metrics)
      add_redis_metrics(metrics)
      add_webhook_metrics(metrics)
      add_queue_metrics(metrics)
      add_growth_metrics(metrics)
      add_operational_alerts(metrics)
    end
  end

  private

  def add_chatwoot_meta(metrics)
    metrics['Chatwoot edition'] = if ChatwootApp.enterprise?
                                    'Enterprise'
                                  elsif ChatwootApp.custom?
                                    'Custom'
                                  else
                                    'Community'
                                  end
    metrics['Database Migrations'] = ActiveRecord::Base.connection.migration_context.needs_migration? ? 'pending' : 'completed'
    metrics['Chatwoot version'] = Chatwoot.config[:version]
    metrics['Git SHA'] = GIT_HASH
  end

  def add_postgres_status(metrics)
    metrics['Postgres alive'] = ActiveRecord::Base.connection.active? ? 'true' : 'false'
  end

  def add_redis_metrics(metrics)
    redis = Redis.new(Redis::Config.app)
    return metrics['Redis alive'] = 'false' unless redis.ping == 'PONG'

    redis_server = redis.info
    metrics['Redis alive'] = 'true'
    metrics['Redis version'] = redis_server['redis_version']
    metrics['Redis connected clients'] = redis_server['connected_clients']
    metrics["Redis 'maxclients'"] = redis_server['maxclients']
    metrics['Redis memory used'] = redis_server['used_memory_human']
    metrics['Redis memory peak'] = redis_server['used_memory_peak_human']
    metrics['Redis total memory available'] = redis_server['total_system_memory_human']
    metrics["Redis 'maxmemory'"] = redis_server['maxmemory']
    metrics["Redis 'maxmemory_policy'"] = redis_server['maxmemory_policy']
  rescue Redis::CannotConnectError
    metrics['Redis alive'] = 'false'
  end

  def add_webhook_metrics(metrics)
    metrics['Inbound webhook events total'] = InboundWebhookEvent.count
    metrics['Inbound webhook backlog'] = InboundWebhookEvent.where(status: %i[received processing]).count
    metrics['Inbound webhook failed'] = InboundWebhookEvent.failed.count
    metrics['Inbound webhook invalid'] = InboundWebhookEvent.invalid.count
    metrics['Inbound webhook received (24h)'] = InboundWebhookEvent.where(created_at: 24.hours.ago..Time.current).count
    metrics['Inbound webhook processed (24h)'] = InboundWebhookEvent.processed.where(processed_at: 24.hours.ago..Time.current).count
    metrics['Inbound webhook failed (24h)'] = InboundWebhookEvent.failed.where(updated_at: 24.hours.ago..Time.current).count
    metrics['Inbound webhook oldest backlog age'] = oldest_backlog_age

    WEBHOOK_SOURCES.each do |source|
      metrics["#{source.titleize} inbound events (24h)"] =
        InboundWebhookEvent.where(source: source, created_at: 24.hours.ago..Time.current).count
    end
  end

  def add_queue_metrics(metrics)
    metrics['Sidekiq queue webhooks size'] = sidekiq_queue_size('webhooks')
    metrics['Sidekiq queue media size'] = sidekiq_queue_size('media')
    metrics['Sidekiq queue critical size'] = sidekiq_queue_size('critical')
    metrics['Sidekiq queue default size'] = sidekiq_queue_size('default')
  end

  def add_growth_metrics(metrics)
    metrics['Messages total'] = Message.count
    metrics['Messages last 30 days'] = Message.where(created_at: 30.days.ago..Time.current).count
    metrics['Conversations total'] = Conversation.count
    metrics['Contacts total'] = Contact.count

    top_account = Message.group(:account_id).order(Arel.sql('COUNT(*) DESC')).limit(1).count.first
    if top_account.present?
      account_id, count = top_account
      metrics['Top account by messages'] = "account_id=#{account_id} count=#{count}"
    end

    table_sizes.each do |table_name, table_size|
      metrics["Table size #{table_name}"] = table_size
    end
  end

  def add_operational_alerts(metrics)
    metrics.merge!(Monitoring::OperationalAlertsService.new(metrics).perform)
  end

  def oldest_backlog_age
    oldest_event = InboundWebhookEvent.where(status: %i[received processing]).order(:created_at).first
    return 'none' unless oldest_event

    seconds = (Time.current - oldest_event.created_at).to_i
    "#{seconds}s"
  end

  def sidekiq_queue_size(queue_name)
    Sidekiq::Queue.new(queue_name).size
  rescue NameError
    'unavailable'
  end

  def table_sizes
    TRACKED_TABLES.index_with do |table_name|
      ActiveRecord::Base.connection.select_value(
        "SELECT pg_size_pretty(pg_total_relation_size('#{table_name}'))"
      )
    end
  rescue StandardError
    {}
  end
end
