# frozen_string_literal: true

FactoryBot.define do
  factory :team_managed_company do
    account
    team
    managed_company
  end
end
