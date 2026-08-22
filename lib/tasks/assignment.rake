namespace :assignment do
  desc 'Report auto-assignment health per account: feature flag, inboxes, unassigned backlog, agents online now.'
  task status: :environment do
    Account.find_each do |account|
      online = OnlineStatusTracker.get_available_users(account.id).select { |_k, v| v == 'online' }.keys
      inboxes = account.inboxes.includes(:members)
      disabled = inboxes.reject(&:enable_auto_assignment?)
      memberless = inboxes.select { |inbox| inbox.members.empty? }
      backlog = account.conversations.unassigned.open

      puts "\nAccount #{account.id} (#{account.name})"
      puts "  assignment_v2 (periodic retry): #{account.feature_enabled?('assignment_v2') ? 'ON' : 'OFF -- backlog is never retried'}"
      puts "  agents online right now: #{online.size}"
      puts "  unassigned open conversations: #{backlog.count}"
      puts "  oldest unassigned: #{backlog.minimum(:created_at) || 'n/a'}"
      puts "  inboxes with auto assignment OFF: #{disabled.size}#{disabled.any? ? " -> #{disabled.map(&:name).join(', ')}" : ''}"
      puts "  inboxes with no members: #{memberless.size}#{memberless.any? ? " -> #{memberless.map(&:name).join(', ')}" : ''}"
    end
  end

  desc 'Enable assignment_v2 on existing accounts so the periodic retry job runs. Dry run unless APPLY=true.'
  task enable_v2: :environment do
    apply = ENV['APPLY'] == 'true'

    Account.find_each do |account|
      next if account.feature_enabled?('assignment_v2')

      puts "#{apply ? 'Enabling' : '[dry run] would enable'} assignment_v2 on account #{account.id} (#{account.name})"
      account.enable_features!('assignment_v2') if apply
    end

    puts "\nDry run. Re-run with APPLY=true to persist." unless apply
  end

  desc 'Assign the unassigned open backlog round-robin over inbox members, ignoring online status. Dry run unless APPLY=true.'
  task backfill: :environment do
    apply = ENV['APPLY'] == 'true'
    notify = ENV['NOTIFY'] == 'true'
    limit = ENV.fetch('LIMIT', 500).to_i
    older_than = ENV['OLDER_THAN_DAYS'].presence&.to_i
    assigned = 0

    accounts = ENV['ACCOUNT_ID'].present? ? Account.where(id: ENV.fetch('ACCOUNT_ID')) : Account.all
    accounts.find_each do |account|
      inboxes = account.inboxes.includes(:members)
      inboxes = inboxes.where(id: ENV.fetch('INBOX_ID')) if ENV['INBOX_ID'].present?

      inboxes.find_each do |inbox|
        break if assigned >= limit

        agent_ids = inbox.members.ids
        if agent_ids.empty?
          puts "  skip inbox #{inbox.id} (#{inbox.name}): no members"
          next
        end

        conversations = inbox.conversations.unassigned.open.order(created_at: :asc)
        conversations = conversations.where('conversations.created_at < ?', older_than.days.ago) if older_than
        conversations = conversations.limit(limit - assigned).to_a
        next if conversations.empty?

        conversations.each_with_index do |conversation, index|
          agent_id = agent_ids[index % agent_ids.size]
          assigned += 1
          next unless apply

          if notify
            conversation.update!(assignee_id: agent_id)
          else
            conversation.update_columns(assignee_id: agent_id, updated_at: Time.current)
          end
        end

        puts "  inbox #{inbox.id} (#{inbox.name}): #{apply ? 'assigned' : 'would assign'} #{conversations.size} across #{agent_ids.size} agents"
      end
    end

    puts "\nTotal #{apply ? 'assigned' : 'to assign'}: #{assigned} (LIMIT=#{limit})"
    puts 'Dry run. Re-run with APPLY=true to persist.' unless apply
    puts 'Silent mode: no notifications or activity messages. Pass NOTIFY=true to dispatch them.' if apply && !notify
  end
end
