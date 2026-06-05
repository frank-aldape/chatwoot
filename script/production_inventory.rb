# frozen_string_literal: true

require 'erb'
require 'json'
require 'yaml'
require 'sidekiq/api'

connection = ActiveRecord::Base.connection

def sidekiq_queue_names
  config = YAML.safe_load(
    ERB.new(File.read(Rails.root.join('config/sidekiq.yml'))).result,
    permitted_classes: [Symbol],
    aliases: true
  )
  config[:queues] || config['queues'] || []
end

def select_all_hashes(connection, sql)
  connection.select_all(sql).map(&:symbolize_keys)
end

db_inventory = {
  database: connection.current_database,
  adapter: connection.adapter_name,
  version: connection.select_value('SELECT version()'),
  server_version_num: connection.select_value('SHOW server_version_num'),
  max_connections: connection.select_value('SHOW max_connections').to_i,
  active_connections: connection.select_value('SELECT count(*) FROM pg_stat_activity').to_i,
  extensions: select_all_hashes(connection, <<~SQL)
    SELECT extname, extversion
    FROM pg_extension
    ORDER BY extname
  SQL
}

largest_tables = select_all_hashes(connection, <<~SQL)
  SELECT
    relname AS table_name,
    n_live_tup AS estimated_live_rows,
    pg_size_pretty(pg_total_relation_size(relid)) AS total_size,
    pg_total_relation_size(relid) AS total_size_bytes
  FROM pg_stat_user_tables
  ORDER BY pg_total_relation_size(relid) DESC
  LIMIT 20
SQL

queues = sidekiq_queue_names.map do |queue_name|
  queue = Sidekiq::Queue.new(queue_name)
  {
    name: queue_name,
    size: queue.size,
    latency_seconds: queue.latency.round(2)
  }
end

sidekiq_processes = Sidekiq::ProcessSet.new.map do |process|
  {
    identity: process['identity'],
    concurrency: process['concurrency'],
    queues: process['queues'],
    busy: process['busy'],
    beat: process['beat']
  }
end

inventory = {
  generated_at: Time.current.iso8601,
  runtime: {
    rails_env: Rails.env,
    ruby_version: RUBY_VERSION,
    rails_version: Rails.version,
    active_storage_service: Rails.application.config.active_storage.service,
    rails_max_threads: ENV.fetch('RAILS_MAX_THREADS', nil),
    sidekiq_concurrency: ENV.fetch('SIDEKIQ_CONCURRENCY', nil),
    rails_replicas: ENV.fetch('RAILS_REPLICAS', nil),
    sidekiq_replicas: ENV.fetch('SIDEKIQ_REPLICAS', nil)
  },
  database: db_inventory,
  largest_tables: largest_tables,
  sidekiq: {
    queue_latency_max_seconds: ENV.fetch('QUEUE_LATENCY_MAX_SECONDS', nil),
    queues: queues,
    processes: sidekiq_processes
  }
}

puts JSON.pretty_generate(inventory)
