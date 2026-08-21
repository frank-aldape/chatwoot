# == Schema Information
#
# Table name: teams
#
#  id                :bigint           not null, primary key
#  allow_auto_assign :boolean          default(TRUE)
#  description       :text
#  name              :string           not null
#  created_at        :datetime         not null
#  updated_at        :datetime         not null
#  account_id        :bigint           not null
#
# Indexes
#
#  index_teams_on_account_id           (account_id)
#  index_teams_on_name_and_account_id  (name,account_id) UNIQUE
#
class Team < ApplicationRecord
  include AccountCacheRevalidator

  belongs_to :account
  has_many :team_members, dependent: :destroy_async
  has_many :members, through: :team_members, source: :user
  has_many :team_managed_companies, dependent: :destroy
  has_many :managed_companies, through: :team_managed_companies
  has_many :team_managed_company_channel_rules, dependent: :destroy
  has_many :team_inboxes, dependent: :destroy
  has_many :inboxes, through: :team_inboxes
  has_many :conversations, dependent: :nullify

  validates :name,
            presence: { message: I18n.t('errors.validations.presence') },
            uniqueness: { scope: :account_id }

  # Mailboxes this team serves, as email local-parts ('compras', 'ventas').
  # The domain is deliberately ignored: one rule covers every company.
  scope :serving_mailbox, lambda { |mailbox|
    where('teams.mailboxes @> ARRAY[?]::text[]', mailbox.to_s)
  }

  before_validation do
    self.name = name.downcase if attribute_present?('name')
  end

  before_validation :normalize_mailboxes
  # Adding a mailbox links matching inboxes that already exist. Removing one does
  # not revoke links already granted -- unlink per inbox from its settings.
  after_commit :sync_mailbox_inboxes, if: :saved_change_to_mailboxes?

  # Adds multiple members to the team
  # @param user_ids [Array<Integer>] Array of user IDs to add as members
  # @return [Array<User>] Array of newly added members
  def add_members(user_ids)
    team_members_to_create = user_ids.map { |user_id| { user_id: user_id } }
    created_members = team_members.create(team_members_to_create)
    added_users = created_members.filter_map(&:user)

    update_account_cache
    added_users
  end

  # Removes multiple members from the team
  # @param user_ids [Array<Integer>] Array of user IDs to remove
  # @return [void]
  def remove_members(user_ids)
    team_members.where(user_id: user_ids).destroy_all
    update_account_cache
  end

  def messages
    account.messages.where(conversation_id: conversations.pluck(:id))
  end

  def reporting_events
    account.reporting_events.where(conversation_id: conversations.pluck(:id))
  end

  def push_event_data
    {
      id: id,
      name: name
    }
  end

  private

  def normalize_mailboxes
    return if mailboxes.nil?

    # Accepts 'compras', 'compras@' or a full address; keeps only the local-part.
    self.mailboxes = Array(mailboxes).filter_map do |entry|
      entry.to_s.split('@').first.to_s.strip.downcase.presence
    end.uniq
  end

  def sync_mailbox_inboxes
    return if mailboxes.blank?

    ::Teams::SyncMailboxInboxesJob.perform_later(id)
  end
end

Team.include_mod_with('Audit::Team')
