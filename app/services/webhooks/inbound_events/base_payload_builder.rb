require 'digest'

class Webhooks::InboundEvents::BasePayloadBuilder
  private

  def payload_digest(payload)
    Digest::SHA256.hexdigest(payload.to_json)
  end

  def build_event_key(source:, account_id:, event_type:, external_id:, payload:)
    dedupe_key = external_id.presence || payload_digest(payload)
    [source, account_id || 'global', event_type, dedupe_key].join(':')
  end
end
