# frozen_string_literal: true

require 'erb'
require 'fileutils'
require 'json'
require 'net/http'
require 'open3'
require 'sidekiq/api'
require 'uri'
require 'yaml'

def percent(value, total)
  return 0.0 if total.to_f.zero?

  ((value.to_f / total.to_f) * 100).round(2)
end

def threshold(name, default)
  ENV.fetch(name, default).to_f
end

def sidekiq_queue_names
  config = YAML.safe_load(
    ERB.new(File.read(Rails.root.join('config/sidekiq.yml'))).result,
    permitted_classes: [Symbol],
    aliases: true
  )
  config[:queues] || config['queues'] || []
end

def disk_usage(path)
  stdout, status = Open3.capture2('df', '-P', path.to_s)
  raise "df failed for #{path}" unless status.success?

  fields = stdout.lines.last.split
  {
    filesystem: fields[0],
    used_percent: fields[4].delete('%').to_i,
    mounted_on: fields[5]
  }
end

def boolean_env(name, default)
  value = ENV.fetch(name, default).to_s.downcase
  %w[1 true yes y].include?(value)
end

def notification_signature(payload)
  JSON.generate(
    status: payload[:status],
    warnings: payload[:warnings].sort
  )
end

def notification_state_path
  Rails.root.join('tmp/production_alerts_check_state.json')
end

def notification_state
  path = notification_state_path
  return {} unless File.exist?(path)

  JSON.parse(File.read(path))
rescue JSON::ParserError
  {}
end

def write_notification_state(payload)
  FileUtils.mkdir_p(notification_state_path.dirname)
  File.write(
    notification_state_path,
    JSON.pretty_generate(
      last_status: payload[:status],
      last_signature: notification_signature(payload),
      last_sent_at: Time.current.iso8601
    )
  )
end

def should_notify?(payload)
  return false if ENV.fetch('ALERT_WEBHOOK_URL', '').empty?

  state = notification_state
  previous_status = state.fetch('last_status', nil)
  current_signature = notification_signature(payload)

  return true if payload[:status] == 'warning' && current_signature != state.fetch('last_signature', nil)
  return true if payload[:status] == 'ok' && previous_status == 'warning' && boolean_env('ALERT_NOTIFY_RECOVERY', true)
  return true if payload[:status] == 'ok' && boolean_env('ALERT_NOTIFY_ON_OK', false)

  last_sent_at = Time.zone.parse(state.fetch('last_sent_at', nil).to_s)
  repeat_minutes = threshold('ALERT_REPEAT_MINUTES', 60)

  payload[:status] == 'warning' && (last_sent_at.blank? || last_sent_at < repeat_minutes.minutes.ago)
rescue ArgumentError
  true
end

def send_alert_notification(payload)
  uri = URI.parse(ENV.fetch('ALERT_WEBHOOK_URL'))
  request = Net::HTTP::Post.new(uri)
  request['Content-Type'] = 'application/json'
  request.body = JSON.generate(
    text: "#{ENV.fetch('ALERT_INSTANCE_NAME', 'Chatwoot production')} #{payload[:status]}",
    status: payload[:status],
    generated_at: payload[:generated_at],
    warnings: payload[:warnings],
    metrics: payload[:metrics]
  )

  Net::HTTP.start(uri.host, uri.port, use_ssl: uri.scheme == 'https', read_timeout: threshold('ALERT_WEBHOOK_TIMEOUT_SECONDS', 10)) do |http|
    response = http.request(request)
    raise "alert webhook failed with HTTP #{response.code}" unless response.is_a?(Net::HTTPSuccess)
  end

  write_notification_state(payload)
end

warnings = []
metrics = {}

connection = ActiveRecord::Base.connection
max_connections = connection.select_value('SHOW max_connections').to_i
active_connections = connection.select_value('SELECT count(*) FROM pg_stat_activity').to_i
db_usage = percent(active_connections, max_connections)
metrics[:database] = {
  active_connections: active_connections,
  max_connections: max_connections,
  used_percent: db_usage
}
warnings << "database connections at #{db_usage}% (#{active_connections}/#{max_connections})" if db_usage >= threshold('ALERT_DB_CONNECTIONS_WARN_PERCENT', 80)

queue_latency_limit = threshold('ALERT_SIDEKIQ_QUEUE_LATENCY_WARN_SECONDS', ENV.fetch('QUEUE_LATENCY_MAX_SECONDS', 300))
queue_size_limit = threshold('ALERT_SIDEKIQ_QUEUE_SIZE_WARN_COUNT', 100)
queues = sidekiq_queue_names.map do |queue_name|
  queue = Sidekiq::Queue.new(queue_name)
  queue_metric = {
    name: queue_name,
    size: queue.size,
    latency_seconds: queue.latency.round(2)
  }
  warnings << "sidekiq queue #{queue_name} latency #{queue_metric[:latency_seconds]}s" if queue_metric[:latency_seconds] >= queue_latency_limit
  warnings << "sidekiq queue #{queue_name} size #{queue_metric[:size]}" if queue_metric[:size] >= queue_size_limit
  queue_metric
end
retry_count = Sidekiq::RetrySet.new.size
dead_count = Sidekiq::DeadSet.new.size
metrics[:sidekiq] = {
  queues: queues,
  retries: retry_count,
  dead: dead_count,
  processes: Sidekiq::ProcessSet.new.size
}
warnings << "sidekiq retries at #{retry_count}" if retry_count >= threshold('ALERT_SIDEKIQ_RETRY_WARN_COUNT', 100)
warnings << "sidekiq dead jobs at #{dead_count}" if dead_count >= threshold('ALERT_SIDEKIQ_DEAD_WARN_COUNT', 10)

redis_info = $alfred.with { |redis| redis.info }
used_memory = redis_info.fetch('used_memory', '0').to_i
maxmemory = redis_info.fetch('maxmemory', '0').to_i
redis_memory_percent = percent(used_memory, maxmemory)
metrics[:redis] = {
  used_memory: used_memory,
  maxmemory: maxmemory,
  memory_used_percent: maxmemory.positive? ? redis_memory_percent : nil,
  connected_clients: redis_info.fetch('connected_clients', nil),
  evicted_keys: redis_info.fetch('evicted_keys', nil),
  loading: redis_info.fetch('loading', nil),
  aof_enabled: redis_info.fetch('aof_enabled', nil),
  aof_last_bgrewrite_status: redis_info.fetch('aof_last_bgrewrite_status', nil),
  rdb_last_bgsave_status: redis_info.fetch('rdb_last_bgsave_status', nil)
}
if maxmemory.positive? && redis_memory_percent >= threshold('ALERT_REDIS_MEMORY_WARN_PERCENT', 80)
  warnings << "redis memory at #{redis_memory_percent}%"
end
warnings << 'redis RDB last save failed' if redis_info.fetch('rdb_last_bgsave_status', 'ok') != 'ok'
warnings << 'redis AOF last rewrite failed' if redis_info.fetch('aof_last_bgrewrite_status', 'ok') != 'ok'

storage_path = Rails.root.join('storage')
if Rails.application.config.active_storage.service.to_s == 'local' && File.directory?(storage_path)
  disk = disk_usage(storage_path)
  metrics[:active_storage_disk] = disk
  warnings << "active storage disk at #{disk[:used_percent]}%" if disk[:used_percent] >= threshold('ALERT_STORAGE_DISK_WARN_PERCENT', 85)
end

root_disk = disk_usage(Rails.root)
metrics[:root_disk] = root_disk
warnings << "root disk at #{root_disk[:used_percent]}%" if root_disk[:used_percent] >= threshold('ALERT_ROOT_DISK_WARN_PERCENT', 85)

payload = {
  generated_at: Time.current.iso8601,
  status: warnings.empty? ? 'ok' : 'warning',
  thresholds: {
    db_connections_percent: threshold('ALERT_DB_CONNECTIONS_WARN_PERCENT', 80),
    sidekiq_queue_latency_seconds: queue_latency_limit,
    sidekiq_queue_size_count: queue_size_limit,
    redis_memory_percent: threshold('ALERT_REDIS_MEMORY_WARN_PERCENT', 80),
    storage_disk_percent: threshold('ALERT_STORAGE_DISK_WARN_PERCENT', 85),
    root_disk_percent: threshold('ALERT_ROOT_DISK_WARN_PERCENT', 85)
  },
  warnings: warnings,
  metrics: metrics
}

puts JSON.pretty_generate(payload)

if should_notify?(payload)
  begin
    send_alert_notification(payload)
  rescue StandardError => e
    warn "alert notification failed: #{e.message}"
    exit(1)
  end
end

exit(warnings.empty? ? 0 : 1)
