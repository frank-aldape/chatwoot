class Webhooks::InboundEvents::IngestService
  pattr_initialize [:source!, :payload!]

  def perform
    build_events.filter_map do |event_attributes|
      create_event(event_attributes)
    end
  end

  private

  def build_events
    case source
    when 'whatsapp'
      [Webhooks::InboundEvents::WhatsappPayloadBuilder.new(payload).build]
    when 'instagram'
      Webhooks::InboundEvents::InstagramPayloadBuilder.new(payload).build
    else
      []
    end
  end

  def create_event(attributes)
    process_after = attributes.delete(:process_after)
    event = find_or_create_event(attributes)
    enqueue_processing(event, process_after) if event.previously_new_record? && event.received?
    event
  end

  def find_or_create_event(attributes)
    InboundWebhookEvent.create!(attributes)
  rescue ActiveRecord::RecordNotUnique
    InboundWebhookEvent.find_by!(event_key: attributes[:event_key])
  end

  def enqueue_processing(event, process_after)
    if process_after.present?
      Webhooks::InboundEventProcessJob.set(wait: process_after).perform_later(event.id)
    else
      Webhooks::InboundEventProcessJob.perform_later(event.id)
    end
  end
end
