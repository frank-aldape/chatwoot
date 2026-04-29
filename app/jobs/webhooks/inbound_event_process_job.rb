class Webhooks::InboundEventProcessJob < ApplicationJob
  queue_as :webhooks

  def perform(event_id)
    event = InboundWebhookEvent.find(event_id)
    return if event.status_processed? || event.status_discarded? || event.status_invalid?

    event.mark_processing!
    process_event(event)
    return if event.status_invalid?

    event.mark_processed!
  rescue StandardError => e
    event&.mark_failed!(e.message)
    raise e
  end

  private

  def process_event(event)
    Rails.logger.info(
      "[InboundWebhookEvent] processing event_id=#{event.id} source=#{event.source} " \
      "account_id=#{event.account_id} inbox_id=#{event.inbox_id} event_type=#{event.event_type} external_id=#{event.external_id}"
    )

    case event.source
    when 'whatsapp'
      Webhooks::WhatsappEventsJob.perform_now(event.payload.deep_symbolize_keys)
    when 'instagram'
      Webhooks::InstagramEventsJob.perform_now([event.payload.deep_symbolize_keys])
    else
      event.mark_invalid!("Unsupported inbound webhook source: #{event.source}")
    end
  end
end
