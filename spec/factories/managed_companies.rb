# frozen_string_literal: true

FactoryBot.define do
  factory :managed_company do
    account
    sequence(:name) { |n| "Managed Company #{n}" }
    sequence(:authorized_domain) { |n| "company#{n}.example.com" }
    status { :active }
  end
end
