class Webhooks::InboundMedia::WhatsappAttachmentService
  pattr_initialize [:message!, :inbox!, :message_type!, :attachment_payload!]

  def perform
    return if message.attachments.exists?

    attachment_file = download_attachment_file
    return if attachment_file.blank?

    message.attachments.create!(
      account_id: message.account_id,
      file_type: file_content_type,
      file: {
        io: attachment_file,
        filename: attachment_file.original_filename,
        content_type: attachment_file.content_type
      }
    )
  end

  private

  def download_attachment_file
    if inbox.channel.provider == 'whatsapp_cloud'
      url_response = HTTParty.get(
        inbox.channel.media_url(attachment_payload[:id]),
        headers: inbox.channel.api_headers
      )
      inbox.channel.authorization_error! if url_response.unauthorized?
      return unless url_response.success?

      return Down.download(url_response.parsed_response['url'], headers: inbox.channel.api_headers)
    end

    Down.download(inbox.channel.media_url(attachment_payload[:id]), headers: inbox.channel.api_headers)
  end

  def file_content_type
    return :image if %w[image sticker].include?(message_type)
    return :audio if %w[audio voice].include?(message_type)
    return :video if message_type == 'video'

    :file
  end
end
