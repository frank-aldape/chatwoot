json.array! @managed_companies do |managed_company|
  json.partial! 'api/v1/models/managed_company', formats: [:json], resource: managed_company
end
