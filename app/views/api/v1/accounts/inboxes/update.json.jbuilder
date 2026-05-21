json.partial! 'api/v1/models/inbox', formats: [:json], resource: @inbox
json.channel_validation_error @channel_validation_error if @channel_validation_error.present?
