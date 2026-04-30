class ManagedCompany < ApplicationRecord
  DOMAIN_REGEX = /\A[a-zA-Z0-9]([a-zA-Z0-9-]*[a-zA-Z0-9])?(\.[a-zA-Z0-9]([a-zA-Z0-9-]*[a-zA-Z0-9])?)+\z/

  belongs_to :account

  has_many :inboxes, dependent: :nullify
  has_many :team_managed_companies, dependent: :destroy
  has_many :teams, through: :team_managed_companies

  enum :status, { active: 0, inactive: 1 }, prefix: true

  validates :name, presence: true, uniqueness: { scope: :account_id }
  validates :authorized_domain,
            presence: true,
            format: { with: DOMAIN_REGEX },
            uniqueness: { scope: :account_id }

  before_validation :normalize_attributes

  scope :ordered_by_name, -> { order('lower(name) ASC') }

  private

  def normalize_attributes
    self.name = name.strip if name.present?
    self.authorized_domain = authorized_domain.to_s.delete_prefix('@').strip.downcase if authorized_domain.present?
  end
end
