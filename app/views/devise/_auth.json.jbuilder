json.data do
  json.partial! 'api/v1/models/user', formats: [:json], resource: resource
end
json.mfa_setup_required resource.mfa_feature_available? && !resource.mfa_enabled? && resource.account_users.administrator.exists?
