# Inbox access is derived from team membership (teams are the permission preset).
# These tasks report on -- and repair -- accounts that still carry inbox_members
# rows with no team backing them.
#
# Usage:
#   bundle exec rake inbox_access:report                  # read-only, run this FIRST
#   bundle exec rake inbox_access:repair                  # dry run, prints the plan
#   APPLY=true bundle exec rake inbox_access:repair       # actually writes
#   ACCOUNT_ID=1 bundle exec rake inbox_access:report     # scope to one account
namespace :inbox_access do
  def accounts_in_scope
    ENV['ACCOUNT_ID'].present? ? Account.where(id: ENV['ACCOUNT_ID']) : Account.all
  end

  # inbox_ids the user reaches through teams
  def team_inbox_ids(account, user_id)
    TeamInbox.joins(team: :team_members)
             .where(account_id: account.id, team_members: { user_id: user_id })
             .distinct.pluck(:inbox_id)
  end

  desc 'Report users who would lose inbox access, and roster drift. Read-only.'
  task report: :environment do
    accounts_in_scope.find_each do |account|
      puts "\n=== Account #{account.id} - #{account.name} ==="

      agents = account.account_users.where(role: :agent).includes(:user)
      losing = []

      agents.each do |account_user|
        user_id = account_user.user_id
        roster = InboxMember.joins(:inbox)
                            .where(inboxes: { account_id: account.id }, user_id: user_id)
                            .distinct.pluck(:inbox_id)
        via_team = team_inbox_ids(account, user_id)
        orphaned = roster - via_team

        next if orphaned.empty?

        losing << [account_user.user.email, orphaned]
      end

      if losing.empty?
        puts 'OK: every agent reaches their inboxes through a team.'
      else
        puts "WARNING: #{losing.size} agent(s) hold inbox access with NO team behind it."
        puts 'They lose access to these inboxes unless you link the inbox to one of their teams:'
        losing.each do |email, inbox_ids|
          names = account.inboxes.where(id: inbox_ids).pluck(:name)
          puts "  #{email}"
          puts "    #{inbox_ids.size} inbox(es): #{names.join(', ')}"
        end
      end

      orphan_inboxes = account.inboxes.where.not(
        id: TeamInbox.where(account_id: account.id).select(:inbox_id)
      )
      if orphan_inboxes.exists?
        puts "\nInboxes not linked to ANY team (only administrators will see them):"
        orphan_inboxes.each { |inbox| puts "  ##{inbox.id} #{inbox.name}" }
      end

      admin_rows = InboxMember.joins(:inbox)
                              .where(inboxes: { account_id: account.id })
                              .where(user_id: account.account_users.where(role: :administrator).select(:user_id))
                              .count
      puts "\nStale roster rows belonging to administrators: #{admin_rows}" if admin_rows.positive?
    end
  end

  desc 'Recompute inbox_members from team membership. Dry run unless APPLY=true.'
  task repair: :environment do
    apply = ENV['APPLY'] == 'true'
    puts apply ? '>>> APPLYING CHANGES' : '>>> DRY RUN (set APPLY=true to write)'

    created = 0
    removed = 0

    accounts_in_scope.find_each do |account|
      admin_ids = account.account_users.where(role: :administrator).pluck(:user_id)

      account.inboxes.find_each do |inbox|
        desired = TeamInbox.joins(team: :team_members)
                           .where(account_id: account.id, inbox_id: inbox.id)
                           .distinct.pluck(Arel.sql('team_members.user_id')) - admin_ids
        current = inbox.inbox_members.pluck(:user_id)

        (desired - current).each do |user_id|
          created += 1
          puts "  + inbox ##{inbox.id} #{inbox.name} -> user #{user_id}"
          inbox.inbox_members.create!(user_id: user_id, access_type: 'team') if apply
        end

        (current - desired).each do |user_id|
          removed += 1
          puts "  - inbox ##{inbox.id} #{inbox.name} -> user #{user_id}"
          inbox.inbox_members.where(user_id: user_id).destroy_all if apply
        end
      end
    end

    puts "\n#{apply ? 'Created' : 'Would create'}: #{created}   #{apply ? 'Removed' : 'Would remove'}: #{removed}"
    puts 'Roster only affects auto-assignment; visibility is derived live from teams.'
  end

  # Mirrors Inbox#channel_email: the channel address wins, the column is the fallback.
  def mailbox_for(inbox)
    address = inbox.channel.try(:email).presence || inbox.email_address
    address.to_s.split('@').first.to_s.strip.downcase
  end

  desc 'Re-link inboxes to the teams whose mailbox rules match them (additive).'
  task sync_mailboxes: :environment do
    accounts_in_scope.find_each do |account|
      account.teams.where.not(mailboxes: []).find_each do |team|
        before = TeamInbox.where(team_id: team.id).count
        ::Teams::SyncMailboxInboxesService.new(team: team).perform
        after = TeamInbox.where(team_id: team.id).count
        puts "#{team.name} [#{team.mailboxes.join(', ')}]: #{before} -> #{after}"
      end
    end
  end

  desc 'List mailboxes no team claims yet, so nobody but admins can see them.'
  task recommend: :environment do
    accounts_in_scope.find_each do |account|
      puts "\n=== Account #{account.id} - #{account.name} ==="

      claimed = account.teams.pluck(:mailboxes).flatten.uniq
      orphans = Hash.new { |hash, key| hash[key] = [] }

      account.inboxes.includes(:channel).find_each do |inbox|
        next if TeamInbox.exists?(inbox_id: inbox.id)

        orphans[mailbox_for(inbox).presence || '(sin correo)'] << inbox
      end

      if orphans.empty?
        puts 'OK: every inbox belongs to at least one team.'
        next
      end

      orphans.sort_by { |_, inboxes| -inboxes.size }.each do |mailbox, inboxes|
        if claimed.include?(mailbox)
          puts "#{mailbox}@: #{inboxes.size} inbox(es) NOT linked even though a team claims this mailbox."
          puts '  -> run `rake inbox_access:sync_mailboxes` to repair.'
        else
          puts "#{mailbox}@: #{inboxes.size} inbox(es), no team claims this mailbox."
          puts '  -> add it under Settings > Teams > (team) > Buzones, or link the inboxes by hand.'
        end
        inboxes.first(5).each { |inbox| puts "     ##{inbox.id} #{inbox.name}" }
        puts "     ... and #{inboxes.size - 5} more" if inboxes.size > 5
      end
    end
  end
end
