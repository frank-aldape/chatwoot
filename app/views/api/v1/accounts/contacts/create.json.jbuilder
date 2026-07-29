json.payload do
  json.contact do
    # A reused contact belongs to another company's inboxes, so its contact
    # inboxes stay hidden; the client resolves channels via contactable_inboxes.
    json.partial! 'api/v1/models/contact', formats: [:json], resource: @contact, with_contact_inboxes: @reused_contact.nil?
  end
  json.contact_inbox do
    json.inbox @contact_inbox&.inbox
    json.source_id @contact_inbox&.source_id
  end
end
