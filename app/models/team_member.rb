# == Schema Information
#
# Table name: team_members
#
#  id         :bigint           not null, primary key
#  created_at :datetime         not null
#  updated_at :datetime         not null
#  team_id    :bigint           not null
#  user_id    :bigint           not null
#
# Indexes
#
#  index_team_members_on_team_id              (team_id)
#  index_team_members_on_team_id_and_user_id  (team_id,user_id) UNIQUE
#  index_team_members_on_user_id              (user_id)
#
class TeamMember < ApplicationRecord
  belongs_to :user
  belongs_to :team
  validates :user_id, uniqueness: { scope: :team_id }

  after_create :sync_team_inbox_roster
  after_destroy :sync_team_inbox_roster

  private

  def sync_team_inbox_roster
    team.inboxes.find_each do |inbox|
      InboxMembers::AccessService.new(inbox: inbox, user: user).sync!
    end
    team.account.update_cache_key('inbox')
  end
end

TeamMember.include_mod_with('Audit::TeamMember')
