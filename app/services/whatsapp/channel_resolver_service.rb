class Whatsapp::ChannelResolverService
  pattr_initialize [:params!]

  def perform
    return channel_from_business_payload if params[:object] == 'whatsapp_business_account'

    channel_from_phone_number
  end

  private

  def channel_from_phone_number
    return unless params[:phone_number]

    Channel::Whatsapp.find_by(phone_number: params[:phone_number])
  end

  def channel_from_business_payload
    phone_number = "+#{params.dig(:entry, 0, :changes, 0, :value, :metadata, :display_phone_number)}"
    phone_number_id = params.dig(:entry, 0, :changes, 0, :value, :metadata, :phone_number_id)
    channel = Channel::Whatsapp.find_by(phone_number: phone_number)
    return unless channel
    return channel if channel.provider_config['phone_number_id'] == phone_number_id
  end
end
