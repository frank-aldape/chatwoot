# == Schema Information
#
# Table name: channel_api
#
#  id                    :bigint           not null, primary key
#  additional_attributes :jsonb
#  hmac_mandatory        :boolean          default(FALSE)
#  hmac_token            :string
#  identifier            :string
#  webhook_url           :string
#  created_at            :datetime         not null
#  updated_at            :datetime         not null
#  account_id            :integer          not null
#
# Indexes
#
#  index_channel_api_on_hmac_token  (hmac_token) UNIQUE
#  index_channel_api_on_identifier  (identifier) UNIQUE
#

class Channel::Api < ApplicationRecord
  include Channelable

  self.table_name = 'channel_api'
  EDITABLE_ATTRS = [:webhook_url, :hmac_mandatory, { additional_attributes: {} }].freeze

  VALID_PROVIDER_TYPES = %w[linkedin].freeze
  WEBHOOK_URL_REGEX = /\Ahttps?:\/\/\S+\z/i

  has_secure_token :identifier
  has_secure_token :hmac_token
  validate :ensure_valid_agent_reply_time_window
  validate :ensure_valid_additional_attributes
  validates :webhook_url,
            length: { maximum: Limits::URL_LENGTH_LIMIT },
            format: { with: WEBHOOK_URL_REGEX, message: 'must be a valid HTTP/HTTPS URL' },
            allow_blank: true

  def name
    'API'
  end

  def linkedin?
    additional_attributes.to_h['provider_type'] == 'linkedin'
  end

  private

  def ensure_valid_agent_reply_time_window
    return if additional_attributes['agent_reply_time_window'].blank?
    return if additional_attributes['agent_reply_time_window'].to_i.positive?

    errors.add(:agent_reply_time_window, 'agent_reply_time_window must be greater than 0')
  end

  def ensure_valid_additional_attributes
    return if additional_attributes.blank?

    provider_type = additional_attributes['provider_type']
    return if provider_type.blank?

    errors.add(:additional_attributes, "provider_type '#{provider_type}' is not supported") unless VALID_PROVIDER_TYPES.include?(provider_type)
  end
end
