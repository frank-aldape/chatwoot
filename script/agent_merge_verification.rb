# frozen_string_literal: true

# Row-count snapshot of everything AgentMergeAction moves, to run once before a
# merge and once after. The table list is read from the action itself, so a column
# added there is covered here without touching this file.
#
#   BASE_AGENT_ID=1 MERGEE_AGENT_ID=2 bundle exec rails runner script/agent_merge_verification.rb
#
# After a successful merge every mergee count must be 0, and each base count must
# equal the previous pair's sum -- except on the scoped tables, where rows the base
# agent already held for the same inbox/team/conversation are dropped rather than
# duplicated, so the base count can legitimately come out lower.

base_id = ENV.fetch('BASE_AGENT_ID').to_i
mergee_id = ENV.fetch('MERGEE_AGENT_ID').to_i

def count_row(label, scope, base_id, mergee_id)
  [label, scope.call(base_id), scope.call(mergee_id)]
end

rows = AgentMergeAction::REPOINTS.map do |model, column|
  count_row("#{model.table_name}.#{column}", ->(id) { model.where(column => id).count }, base_id, mergee_id)
end

rows += AgentMergeAction::SCOPED_REPOINTS.map do |model, _scope_column|
  count_row("#{model.table_name}.user_id", ->(id) { model.where(user_id: id).count }, base_id, mergee_id)
end

rows << count_row('messages.sender_id',
                  ->(id) { Message.where(sender_type: 'User', sender_id: id).count }, base_id, mergee_id)
rows << count_row('notifications.secondary_actor_id',
                  ->(id) { Notification.where(secondary_actor_type: 'User', secondary_actor_id: id).count }, base_id, mergee_id)

[base_id, mergee_id].each do |id|
  user = User.find_by(id: id)
  puts "usuario #{id}: #{user ? "#{user.email} -- #{user.name}" : 'NO EXISTE'}"
end
puts

width = rows.map { |row| row.first.length }.max
puts format("%-#{width}s  %10s  %10s", 'tabla.columna', "base #{base_id}", "dup #{mergee_id}")
rows.each { |label, base_count, mergee_count| puts format("%-#{width}s  %10d  %10d", label, base_count, mergee_count) }
puts
puts format("%-#{width}s  %10d  %10d", 'TOTAL', rows.sum { |row| row[1] }, rows.sum { |row| row[2] })
