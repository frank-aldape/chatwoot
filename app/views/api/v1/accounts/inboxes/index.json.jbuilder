json.payload do
  json.array! @inboxes do |inbox|
    json.partial! 'api/v1/models/inbox', formats: [:json], resource: inbox, summary: true
  end
end
