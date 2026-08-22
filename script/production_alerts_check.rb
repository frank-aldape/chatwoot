# frozen_string_literal: true

# Manual/cron entry point for the production alert checks.
# The same checks run on a schedule via Internal::ProductionAlertsCheckJob.
#
#   bundle exec rails runner script/production_alerts_check.rb
#
# Exits 0 when every check is within threshold and 1 when warnings are present,
# so any monitor that alerts on a non-zero exit status can consume it.

payload = Internal::ProductionAlertsService.new.perform

puts JSON.pretty_generate(payload)

exit(payload[:warnings].empty? ? 0 : 1)
