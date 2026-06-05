# frozen_string_literal: true

require 'erb'
require 'stringio'
require 'yaml'
require 'sidekiq/api'

failures = []

def check(name)
  print "- #{name}: "
  yield
  puts 'ok'
rescue StandardError => e
  puts "failed (#{e.class}: #{e.message})"
  raise
end

def required_env!(keys)
  missing = keys.select { |key| ENV.fetch(key, '').empty? }
  raise "missing required env vars: #{missing.join(', ')}" if missing.any?
end

def storage_required_env
  case ENV.fetch('ACTIVE_STORAGE_SERVICE')
  when 'local'
    []
  when 'amazon'
    %w[S3_BUCKET_NAME AWS_ACCESS_KEY_ID AWS_SECRET_ACCESS_KEY AWS_REGION]
  when 's3_compatible'
    %w[STORAGE_BUCKET_NAME STORAGE_ACCESS_KEY_ID STORAGE_SECRET_ACCESS_KEY STORAGE_REGION STORAGE_ENDPOINT]
  else
    raise 'ACTIVE_STORAGE_SERVICE must be local, amazon, or s3_compatible'
  end
end

checks = {
  'required production env' => lambda {
    required_env!(%w[POSTGRES_HOST POSTGRES_DATABASE POSTGRES_USERNAME POSTGRES_PASSWORD REDIS_URL ACTIVE_STORAGE_SERVICE])
    required_env!(storage_required_env)
  },
  'database connectivity and headroom' => lambda {
    connection = ActiveRecord::Base.connection
    connection.execute('SELECT 1')
    max_connections = connection.select_value('SHOW max_connections').to_i

    rails_replicas = ENV.fetch('RAILS_REPLICAS', 1).to_i
    sidekiq_replicas = ENV.fetch('SIDEKIQ_REPLICAS', 1).to_i
    rails_threads = ENV.fetch('RAILS_MAX_THREADS', 5).to_i
    sidekiq_concurrency = ENV.fetch('SIDEKIQ_CONCURRENCY', 10).to_i
    maintenance_headroom = ENV.fetch('MAINTENANCE_DB_HEADROOM', 20).to_i
    required_connections = (rails_replicas * rails_threads) + (sidekiq_replicas * sidekiq_concurrency) + maintenance_headroom

    raise "required #{required_connections} DB connections, max_connections is #{max_connections}" if required_connections >= max_connections
  },
  'redis connectivity' => lambda {
    $alfred.with { |redis| redis.ping }
    $velma.with { |redis| redis.ping }
  },
  'active storage upload/download' => lambda {
    blob = ActiveStorage::Blob.create_and_upload!(
      io: StringIO.new("production readiness #{Time.current.iso8601}"),
      filename: "production-readiness-#{Time.current.to_i}.txt",
      content_type: 'text/plain'
    )

    raise 'uploaded blob could not be downloaded' if blob.download.blank?

    blob.purge
  },
  'sidekiq queue latency' => lambda {
    sidekiq_config = YAML.safe_load(
      ERB.new(File.read(Rails.root.join('config/sidekiq.yml'))).result,
      permitted_classes: [Symbol],
      aliases: true
    )
    queue_names = sidekiq_config[:queues] || sidekiq_config['queues'] || []
    max_latency = ENV.fetch('QUEUE_LATENCY_MAX_SECONDS', 300).to_f
    delayed = queue_names.filter_map do |queue_name|
      queue = Sidekiq::Queue.new(queue_name)
      "#{queue_name}=#{queue.latency.round(2)}s" if queue.latency > max_latency
    end

    raise "queues over #{max_latency}s latency: #{delayed.join(', ')}" if delayed.any?
  }
}

checks.each do |name, block|
  check(name, &block)
rescue StandardError => e
  failures << [name, e.message]
end

if failures.any?
  puts "\nProduction readiness failed:"
  failures.each { |name, message| puts "- #{name}: #{message}" }
  exit 1
end

puts "\nProduction readiness passed."
