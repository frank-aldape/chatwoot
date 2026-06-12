class TeamManagedCompanyChannelRule < ApplicationRecord
  CHANNEL_KEYS = %w[
    api
    email
    facebook
    instagram
    line
    linkedin
    sms
    telegram
    tiktok
    twilio_sms
    voice
    web_widget
    whatsapp
    twitter
  ].freeze

  belongs_to :account
  belongs_to :team
  belongs_to :managed_company

  validates :channel_key, inclusion: { in: CHANNEL_KEYS }
  validates :team_id, uniqueness: { scope: [:managed_company_id, :channel_key] }
  validate :ensure_account_integrity

  before_validation :sync_account_id

  def self.channel_key_for_inbox(inbox)
    return 'instagram' if inbox.instagram?
    return 'facebook' if inbox.facebook?
    return 'whatsapp' if inbox.whatsapp? || inbox.twilio_whatsapp?
    return 'linkedin' if inbox.linkedin_bridge?
    return 'twilio_sms' if inbox.twilio?
    return 'web_widget' if inbox.web_widget?
    return 'email' if inbox.email?
    return 'api' if inbox.api?
    return 'sms' if inbox.sms?
    return 'telegram' if inbox.telegram?
    return 'line' if inbox.line?
    return 'tiktok' if inbox.tiktok?
    return 'voice' if inbox.voice?
    return 'twitter' if inbox.twitter?

    nil
  end

  private

  def sync_account_id
    self.account_id ||= team&.account_id || managed_company&.account_id
  end

  def ensure_account_integrity
    return if account_id.blank? || team.blank? || managed_company.blank?

    errors.add(:account_id, :invalid) if team.account_id != account_id || managed_company.account_id != account_id
  end
end
