class Internal::ProductionAlertsCheckJob < ApplicationJob
  queue_as :scheduled_jobs

  def perform
    payload = Internal::ProductionAlertsService.new.perform
    return if payload[:status] == 'ok'

    Rails.logger.warn("[production_alerts] #{payload[:warnings].join('; ')}")
  end
end
