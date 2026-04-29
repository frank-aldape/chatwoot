namespace :observability do
  desc 'Print webhook and growth metrics useful before database partitioning'
  task report: :environment do
    metrics = Monitoring::InstanceMetricsService.new.perform

    puts '== Instance Metrics =='
    metrics.each do |key, value|
      puts "#{key}: #{value}"
    end

    puts "\n== Alert Summary =="
    metrics.select { |key, _value| key.start_with?('Alert ') || key == 'Partitioning recommendation' }.each do |key, value|
      puts "#{key}: #{value}"
    end

    puts "\n== Messages by account (top 10) =="
    Message.group(:account_id).order(Arel.sql('COUNT(*) DESC')).limit(10).count.each do |account_id, count|
      puts "account_id=#{account_id} messages=#{count}"
    end

    puts "\n== Monthly message growth (last 12 months) =="
    Message
      .where(created_at: 12.months.ago..Time.current)
      .group("date_trunc('month', created_at)")
      .order(Arel.sql("date_trunc('month', created_at) DESC"))
      .count
      .each do |month, count|
      puts "#{month.strftime('%Y-%m')}: #{count}"
    end
  end
end
