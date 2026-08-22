# Bulk-resolves the stale open backlog that accumulated while auto-assignment
# had no retry path (see docs/OPERATIONAL_RISKS.md).
#
# Closes silently by default: no CSAT surveys to customers, no webhooks, no
# automation rules, no activity messages. Resolving 8k month-old conversations
# through the normal callbacks would blast surveys at people who wrote weeks ago.
# The trade-off is that reporting will not record these as resolutions.
#
#   bundle exec rake conversations:close_stale                        # dry run
#   APPLY=true bundle exec rake conversations:close_stale             # 30 days, unassigned only
#   APPLY=true DAYS=30 LIMIT=2000 bundle exec rake conversations:close_stale
#   APPLY=true NOTIFY=true bundle exec rake conversations:close_stale # full callbacks, sends CSAT
namespace :conversations do
  desc 'Resolve stale open conversations. Dry run unless APPLY=true.'
  task close_stale: :environment do
    days = ENV.fetch('DAYS', 30).to_i
    limit = ENV.fetch('LIMIT', 1000).to_i
    apply = ENV['APPLY'] == 'true'
    notify = ENV['NOTIFY'] == 'true'
    include_assigned = ENV['INCLUDE_ASSIGNED'] == 'true'
    column = ENV.fetch('BY', 'last_activity_at')

    raise "BY must be last_activity_at or created_at, got #{column}" unless %w[last_activity_at created_at].include?(column)

    cutoff = days.days.ago
    scope = Conversation.open.where("conversations.#{column} < ?", cutoff)
    scope = scope.unassigned unless include_assigned
    scope = scope.where(account_id: ENV.fetch('ACCOUNT_ID')) if ENV['ACCOUNT_ID'].present?
    scope = scope.where(inbox_id: ENV.fetch('INBOX_ID')) if ENV['INBOX_ID'].present?

    total = scope.count
    puts "#{total} open #{include_assigned ? '' : 'unassigned '}conversations with #{column} older than #{days} days (before #{cutoff.to_date})"
    puts "Closing at most #{limit} of them#{apply ? '' : ' -- DRY RUN'}"

    ids = scope.order(column => :asc).limit(limit).pluck(:id)
    if ids.empty?
      puts 'Nothing to close.'
      next
    end

    puts "Oldest: #{scope.where(id: ids).minimum(column)}   Newest: #{scope.where(id: ids).maximum(column)}"

    unless apply
      puts "\nDry run. Re-run with APPLY=true to persist."
      next
    end

    log_path = Rails.root.join("tmp/closed_stale_conversations_#{Time.current.strftime('%Y%m%d%H%M%S')}.txt")
    File.write(log_path, ids.join("\n"))

    closed = 0
    if notify
      Conversation.where(id: ids).find_each do |conversation|
        conversation.update!(status: :resolved)
        closed += 1
      end
    else
      # Mirrors handle_resolved_status_change, which clears waiting_since so the
      # conversation stops counting as waiting in reports.
      Conversation.where(id: ids).in_batches(of: 500) do |batch|
        closed += batch.update_all(status: Conversation.statuses[:resolved], waiting_since: nil, updated_at: Time.current)
      end
    end

    puts "\nClosed #{closed} conversations. Ids written to #{log_path}"
    puts 'Silent close: no CSAT, webhooks, automation rules or activity messages fired.' unless notify
    puts "#{total - closed} still match -- re-run to continue." if total > closed
  end
end
