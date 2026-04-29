class Webhooks::InboundEvents::InstagramPayloadBuilder < Webhooks::InboundEvents::BasePayloadBuilder
  pattr_initialize [:entries!]

  def build
    Array(entries).flat_map do |entry|
      build_for_entry(entry.deep_symbolize_keys)
    end.compact
  end

  private

  def build_for_entry(entry)
    return [build_test_event(entry)] if entry[:changes].present?

    messages_for(entry).map { |messaging| build_message_event(entry, messaging.deep_symbolize_keys) }
  end

  def build_test_event(entry)
    messaging = entry.dig(:changes, 0, :value)&.deep_symbolize_keys
    external_id = messaging&.dig(:message, :mid) || "test-#{entry[:id]}-#{entry[:time]}"
    channel = resolve_channel_for_messaging(messaging)

    build_event_attributes(
      channel: channel,
      event_type: 'test_event',
      external_id: external_id,
      payload: entry
    )
  end

  def build_message_event(entry, messaging)
    payload = entry.merge(messaging: [messaging]).except(:standby)
    external_id = messaging.dig(:message, :mid) || messaging.dig(:read, :mid) || "#{entry[:id]}-#{messaging[:timestamp]}"
    channel = resolve_channel_for_messaging(messaging)
    event_type = supported_event_type(messaging)

    attrs = build_event_attributes(
      channel: channel,
      event_type: event_type,
      external_id: external_id,
      payload: payload
    )
    attrs[:process_after] = 2.seconds if messaging.dig(:message, :is_echo).present?
    attrs
  end

  def build_event_attributes(channel:, event_type:, external_id:, payload:)
    account = channel&.account
    inbox = channel&.inbox

    {
      account_id: account&.id,
      inbox_id: inbox&.id,
      source: 'instagram',
      event_type: event_type,
      external_id: external_id,
      event_key: build_event_key(
        source: 'instagram',
        account_id: account&.id,
        event_type: event_type,
        external_id: external_id,
        payload: payload
      ),
      payload: payload,
      status: valid_event?(event_type, channel) ? :received : :invalid
    }
  end

  def messages_for(entry)
    entry[:messaging].presence || entry[:standby] || []
  end

  def supported_event_type(messaging)
    return 'message' if messaging[:message].present?
    return 'read' if messaging[:read].present?

    'unknown'
  end

  def valid_event?(event_type, channel)
    channel.present? && %w[message read test_event].include?(event_type)
  end

  def resolve_channel_for_messaging(messaging)
    return if messaging.blank?

    instagram_id = if messaging.dig(:message, :is_echo).present?
                     messaging.dig(:sender, :id)
                   else
                     messaging.dig(:recipient, :id)
                   end

    Channel::Instagram.find_by(instagram_id: instagram_id) || Channel::FacebookPage.find_by(instagram_id: instagram_id)
  end
end
