# frozen_string_literal: true

FactoryBot.define do
  factory :team_managed_company_channel_rule do
    account { team.account }
    team
    managed_company
    channel_key { 'email' }
  end
end
