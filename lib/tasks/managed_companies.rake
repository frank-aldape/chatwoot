namespace :managed_companies do
  MANAGED_COMPANY_CHANNEL_LABELS = {
    'email' => 'Email',
    'whatsapp' => 'WhatsApp',
    'instagram' => 'Instagram',
    'facebook' => 'Messenger',
    'linkedin' => 'LinkedIn',
    'telegram' => 'Telegram',
    'tiktok' => 'TikTok',
    'web_widget' => 'Web',
    'twilio_sms' => 'SMS',
    'sms' => 'SMS',
    'line' => 'Line',
    'voice' => 'Voz',
    'twitter' => 'Twitter',
    'api' => 'API'
  }.freeze

  desc 'Provision a managed company: company, team, and channel presets. Dry run unless APPLY=true.'
  task provision: :environment do
    apply = ENV['APPLY'] == 'true'
    account = Account.find(ENV.fetch('ACCOUNT_ID'))
    name = ENV.fetch('NAME')
    domain = ENV.fetch('DOMAIN')
    team_name = ENV['TEAM'].presence
    channels = ENV.fetch('CHANNELS', '').split(',').map(&:strip).reject(&:blank?)

    invalid = channels - TeamManagedCompanyChannelRule::CHANNEL_KEYS
    raise "Unknown channels: #{invalid.join(', ')}. Valid: #{TeamManagedCompanyChannelRule::CHANNEL_KEYS.join(', ')}" if invalid.any?

    puts "#{apply ? 'Provisioning' : '[dry run]'} #{name} (#{domain}) on account #{account.id}"

    ActiveRecord::Base.transaction do
      company = account.managed_companies.find_or_initialize_by(name: name)
      existing_company = company.persisted?
      company.authorized_domain = domain
      company.status = :active
      company.save! if apply
      puts "  company: #{existing_company ? 'reused' : 'created'} #{name} -> #{company.authorized_domain}"

      if team_name
        team = account.teams.find_or_initialize_by(name: team_name)
        puts "  team: #{team.persisted? ? 'reused' : 'created'} #{team_name}"
        team.save! if apply

        if apply
          TeamManagedCompany.find_or_create_by!(account_id: account.id, team_id: team.id, managed_company_id: company.id)
          channels.each do |channel_key|
            TeamManagedCompanyChannelRule.find_or_create_by!(
              account_id: account.id, team_id: team.id, managed_company_id: company.id, channel_key: channel_key
            )
          end
        end
        puts "  channel presets: #{channels.presence&.join(', ') || 'none'}"
      end
    end

    puts "\nCreate these inboxes in the dashboard, then they link to the team automatically:"
    channels.each { |key| puts "  #{name} - #{MANAGED_COMPANY_CHANNEL_LABELS.fetch(key, key)} - [FUNCION]" }
    puts "\nDry run. Re-run with APPLY=true to persist." unless apply
  end

  desc 'Create a saved conversation folder per company for every agent on its teams. Dry run unless APPLY=true.'
  task seed_folders: :environment do
    apply = ENV['APPLY'] == 'true'
    created = 0

    ManagedCompany.status_active.includes(teams: :members).find_each do |company|
      users = company.teams.flat_map(&:members).uniq
      next if users.empty?

      folder_name = "#{company.name} · Abiertas"
      query = {
        payload: [
          { attribute_key: 'managed_company_id', filter_operator: 'equal_to', values: [company.id],
            query_operator: 'and', custom_attribute_type: '' },
          { attribute_key: 'status', filter_operator: 'equal_to', values: ['open'],
            query_operator: nil, custom_attribute_type: '' }
        ]
      }

      users.each do |user|
        next if CustomFilter.exists?(account_id: company.account_id, user_id: user.id, name: folder_name)

        created += 1
        next unless apply

        CustomFilter.create!(
          account_id: company.account_id, user_id: user.id,
          name: folder_name, filter_type: :conversation, query: query
        )
      end
      puts "  #{company.name}: #{users.size} agents"
    end

    puts "\nFolders #{apply ? 'created' : 'to create'}: #{created}"
    puts 'Dry run. Re-run with APPLY=true to persist.' unless apply
  end
end
