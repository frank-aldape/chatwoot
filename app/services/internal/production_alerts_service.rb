require 'erb'
require 'json'
require 'open3'
require 'sidekiq/api'
require 'yaml'

# Collects the runtime health metrics documented in docs/PRODUCTION_OPERATIONS.md
# and notifies ALERT_WEBHOOK_URL when a threshold is crossed.
#
# Called from Internal::ProductionAlertsCheckJob (scheduled) and from
# script/production_alerts_check.rb (manual/cron evidence run).
class Internal::ProductionAlertsService
  # Dedupe state lives in Redis so every replica shares it and a container
  # restart does not resend the same warning.
  STATE_KEY = 'PRODUCTION_ALERTS_STATE'.freeze
  STATE_TTL = 7.days

  def perform
    payload = build_payload
    notify(payload) if should_notify?(payload)
    payload
  end

  private

  def build_payload
    @warnings = []
    @metrics = {}

    check_database
    check_sidekiq
    check_redis
    check_disks

    {
      generated_at: Time.current.iso8601,
      status: @warnings.empty? ? 'ok' : 'warning',
      thresholds: thresholds,
      warnings: @warnings,
      metrics: @metrics
    }
  end

  def thresholds
    {
      db_connections_percent: threshold('ALERT_DB_CONNECTIONS_WARN_PERCENT', 80),
      sidekiq_queue_latency_seconds: queue_latency_limit,
      sidekiq_queue_size_count: queue_size_limit,
      redis_memory_percent: threshold('ALERT_REDIS_MEMORY_WARN_PERCENT', 80),
      storage_disk_percent: threshold('ALERT_STORAGE_DISK_WARN_PERCENT', 85),
      root_disk_percent: threshold('ALERT_ROOT_DISK_WARN_PERCENT', 85)
    }
  end

  def check_database
    connection = ActiveRecord::Base.connection
    max_connections = connection.select_value('SHOW max_connections').to_i
    active_connections = connection.select_value('SELECT count(*) FROM pg_stat_activity').to_i
    used_percent = percent(active_connections, max_connections)

    @metrics[:database] = { active_connections: active_connections, max_connections: max_connections, used_percent: used_percent }
    return if used_percent < threshold('ALERT_DB_CONNECTIONS_WARN_PERCENT', 80)

    @warnings << "database connections at #{used_percent}% (#{active_connections}/#{max_connections})"
  end

  def check_sidekiq
    queues = sidekiq_queue_names.map { |queue_name| queue_metric(queue_name) }
    retry_count = Sidekiq::RetrySet.new.size
    dead_count = Sidekiq::DeadSet.new.size

    @metrics[:sidekiq] = { queues: queues, retries: retry_count, dead: dead_count, processes: Sidekiq::ProcessSet.new.size }
    @warnings << "sidekiq retries at #{retry_count}" if retry_count >= threshold('ALERT_SIDEKIQ_RETRY_WARN_COUNT', 100)
    @warnings << "sidekiq dead jobs at #{dead_count}" if dead_count >= threshold('ALERT_SIDEKIQ_DEAD_WARN_COUNT', 10)
  end

  def queue_metric(queue_name)
    queue = Sidekiq::Queue.new(queue_name)
    metric = { name: queue_name, size: queue.size, latency_seconds: queue.latency.round(2) }

    @warnings << "sidekiq queue #{queue_name} latency #{metric[:latency_seconds]}s" if metric[:latency_seconds] >= queue_latency_limit
    @warnings << "sidekiq queue #{queue_name} size #{metric[:size]}" if metric[:size] >= queue_size_limit
    metric
  end

  def check_redis
    info = $alfred.with(&:info)
    used_memory = info.fetch('used_memory', '0').to_i
    maxmemory = info.fetch('maxmemory', '0').to_i
    memory_percent = percent(used_memory, maxmemory)

    @metrics[:redis] = {
      used_memory: used_memory,
      maxmemory: maxmemory,
      memory_used_percent: maxmemory.positive? ? memory_percent : nil,
      connected_clients: info.fetch('connected_clients', nil),
      evicted_keys: info.fetch('evicted_keys', nil),
      loading: info.fetch('loading', nil),
      aof_enabled: info.fetch('aof_enabled', nil),
      aof_last_bgrewrite_status: info.fetch('aof_last_bgrewrite_status', nil),
      rdb_last_bgsave_status: info.fetch('rdb_last_bgsave_status', nil)
    }

    @warnings << "redis memory at #{memory_percent}%" if maxmemory.positive? && memory_percent >= threshold('ALERT_REDIS_MEMORY_WARN_PERCENT', 80)
    @warnings << 'redis RDB last save failed' if info.fetch('rdb_last_bgsave_status', 'ok') != 'ok'
    @warnings << 'redis AOF last rewrite failed' if info.fetch('aof_last_bgrewrite_status', 'ok') != 'ok'
  end

  def check_disks
    storage_path = Rails.root.join('storage')
    if Rails.application.config.active_storage.service.to_s == 'local' && File.directory?(storage_path)
      disk = disk_usage(storage_path)
      @metrics[:active_storage_disk] = disk
      @warnings << "active storage disk at #{disk[:used_percent]}%" if disk[:used_percent] >= threshold('ALERT_STORAGE_DISK_WARN_PERCENT', 85)
    end

    root_disk = disk_usage(Rails.root)
    @metrics[:root_disk] = root_disk
    @warnings << "root disk at #{root_disk[:used_percent]}%" if root_disk[:used_percent] >= threshold('ALERT_ROOT_DISK_WARN_PERCENT', 85)
  end

  def queue_latency_limit
    @queue_latency_limit ||= threshold('ALERT_SIDEKIQ_QUEUE_LATENCY_WARN_SECONDS', ENV.fetch('QUEUE_LATENCY_MAX_SECONDS', 300))
  end

  def queue_size_limit
    @queue_size_limit ||= threshold('ALERT_SIDEKIQ_QUEUE_SIZE_WARN_COUNT', 100)
  end

  def sidekiq_queue_names
    config = YAML.safe_load(ERB.new(File.read(Rails.root.join('config/sidekiq.yml'))).result, permitted_classes: [Symbol], aliases: true)
    config[:queues] || config['queues'] || []
  end

  def disk_usage(path)
    stdout, status = Open3.capture2('df', '-P', path.to_s)
    raise "df failed for #{path}" unless status.success?

    fields = stdout.lines.last.split
    { filesystem: fields[0], used_percent: fields[4].delete('%').to_i, mounted_on: fields[5] }
  end

  def percent(value, total)
    return 0.0 if total.to_f.zero?

    ((value.to_f / total.to_f) * 100).round(2)
  end

  def threshold(name, default)
    ENV.fetch(name, default).to_f
  end

  def boolean_env(name, default)
    %w[1 true yes y].include?(ENV.fetch(name, default).to_s.downcase)
  end

  def state
    @state ||= JSON.parse(Redis::Alfred.get(STATE_KEY).presence || '{}')
  rescue JSON::ParserError
    {}
  end

  def signature(payload)
    JSON.generate(status: payload[:status], warnings: payload[:warnings].sort)
  end

  def should_notify?(payload)
    return false unless Internal::AlertWebhook.configured?
    return true if payload[:status] == 'warning' && signature(payload) != state['last_signature']
    return true if payload[:status] == 'ok' && state['last_status'] == 'warning' && boolean_env('ALERT_NOTIFY_RECOVERY', true)
    return true if payload[:status] == 'ok' && boolean_env('ALERT_NOTIFY_ON_OK', false)
    return false unless payload[:status] == 'warning'

    last_sent_at = Time.zone.parse(state['last_sent_at'].to_s)
    last_sent_at.blank? || last_sent_at < threshold('ALERT_REPEAT_MINUTES', 60).minutes.ago
  rescue ArgumentError
    true
  end

  def notify(payload)
    Internal::AlertWebhook.post(
      text: "#{ENV.fetch('ALERT_INSTANCE_NAME', 'Chatwoot production')} #{payload[:status]}",
      status: payload[:status],
      generated_at: payload[:generated_at],
      warnings: payload[:warnings],
      metrics: payload[:metrics]
    )

    write_state(payload)
  end

  def write_state(payload)
    Redis::Alfred.set(
      STATE_KEY,
      JSON.generate(last_status: payload[:status], last_signature: signature(payload), last_sent_at: Time.current.iso8601),
      ex: STATE_TTL.to_i
    )
  end
end
