# == Schema Information
#
# Table name: inbound_webhook_events
#
#  id            :bigint           not null, primary key
#  error_message :text
#  event_key     :string           not null
#  event_type    :string           not null
#  external_id   :string
#  payload       :jsonb            not null
#  processed_at  :datetime
#  source        :string           not null
#  status        :integer          default("received"), not null
#  created_at    :datetime         not null
#  updated_at    :datetime         not null
#  account_id    :bigint
#  inbox_id      :bigint
#
# Indexes
#
#  idx_inbound_webhook_events_account_status     (account_id,status,created_at)
#  index_inbound_webhook_events_on_account_id    (account_id)
#  index_inbound_webhook_events_on_event_key     (event_key) UNIQUE
#  index_inbound_webhook_events_on_external_id   (source,external_id)
#  index_inbound_webhook_events_on_inbox_id      (inbox_id)
#
class InboundWebhookEvent < ApplicationRecord
  belongs_to :account, optional: true
  belongs_to :inbox, optional: true

  enum status: {
    received: 0,
    processing: 1,
    processed: 2,
    failed: 3,
    invalid: 4,
    discarded: 5
  }

  validates :source, presence: true
  validates :event_type, presence: true
  validates :event_key, presence: true, uniqueness: true
  validates :payload, presence: true

  scope :recent_first, -> { order(created_at: :desc) }

  def mark_processing!
    update!(status: :processing, error_message: nil)
  end

  def mark_processed!
    update!(status: :processed, processed_at: Time.current, error_message: nil)
  end

  def mark_failed!(message)
    update!(status: :failed, error_message: message.to_s.truncate(1_000))
  end

  def mark_invalid!(message)
    update!(status: :invalid, error_message: message.to_s.truncate(1_000))
  end
end
