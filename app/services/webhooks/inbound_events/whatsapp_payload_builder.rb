class Webhooks::InboundEvents::WhatsappPayloadBuilder < Webhooks::InboundEvents::BasePayloadBuilder
  pattr_initialize [:payload!]

  def build
    params = payload.deep_symbolize_keys
    channel = Whatsapp::ChannelResolverService.new(params).perform
    account = channel&.account
    inbox = channel&.inbox
    external_id = params.dig(:statuses, 0, :id) || params.dig(:messages, 0, :id)
    event_type = if params[:statuses].present?
                   "status_#{params.dig(:statuses, 0, :status)}"
                 elsif params[:messages].present?
                   params.dig(:messages, 0, :type).presence || 'message'
                 else
                   'unknown'
                 end

    {
      account_id: account&.id,
      inbox_id: inbox&.id,
      source: 'whatsapp',
      event_type: event_type,
      external_id: external_id,
      event_key: build_event_key(
        source: 'whatsapp',
        account_id: account&.id,
        event_type: event_type,
        external_id: external_id,
        payload: params
      ),
      payload: params,
      status: valid_payload?(params, channel) ? :received : :invalid
    }
  end

  private

  def valid_payload?(params, channel)
    return false if channel.blank?
    return true if params[:statuses].present?
    return true if params[:messages].present? && params[:contacts].present?

    false
  end
end
