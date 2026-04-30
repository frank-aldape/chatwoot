FactoryBot.define do
  factory :team_inbox do
    account { team.account }
    team
    inbox
  end
end
