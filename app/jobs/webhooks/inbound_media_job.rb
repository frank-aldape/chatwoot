class Webhooks::InboundMediaJob < ApplicationJob
  queue_as :media

  def perform(message_id, inbox_id, message_type, attachment_payload)
    message = Message.find(message_id)
    inbox = Inbox.find(inbox_id)

    Webhooks::InboundMedia::WhatsappAttachmentService.new(
      message: message,
      inbox: inbox,
      message_type: message_type,
      attachment_payload: attachment_payload.deep_symbolize_keys
    ).perform
  end
end
