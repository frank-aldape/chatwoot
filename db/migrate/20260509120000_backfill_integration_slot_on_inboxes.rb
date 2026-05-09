class BackfillIntegrationSlotOnInboxes < ActiveRecord::Migration[7.1]
  # Populates integration_slot for inboxes that already have a managed_company_id.
  # Must run after 20260508120000_add_unique_slot_indexes_to_inboxes.rb.
  #
  # Mirrors the Ruby logic in Inbox#managed_company_integration_slot using raw SQL
  # to avoid loading every inbox into memory and to stay independent of future
  # model changes.
  def up
    # Channel::Whatsapp → always 'whatsapp'
    execute <<~SQL
      UPDATE inboxes
      SET integration_slot = 'whatsapp'
      WHERE managed_company_id IS NOT NULL
        AND channel_type = 'Channel::Whatsapp';
    SQL

    # Channel::TwilioSms with medium = 1 (whatsapp) → 'whatsapp'
    execute <<~SQL
      UPDATE inboxes
      SET integration_slot = 'whatsapp'
      WHERE managed_company_id IS NOT NULL
        AND channel_type = 'Channel::TwilioSms'
        AND channel_id IN (
          SELECT id FROM channel_twilio_sms WHERE medium = 1
        );
    SQL

    # Channel::Instagram (direct) → always 'instagram'
    execute <<~SQL
      UPDATE inboxes
      SET integration_slot = 'instagram'
      WHERE managed_company_id IS NOT NULL
        AND channel_type = 'Channel::Instagram';
    SQL

    # Channel::FacebookPage with instagram_id set → 'instagram'
    execute <<~SQL
      UPDATE inboxes
      SET integration_slot = 'instagram'
      WHERE managed_company_id IS NOT NULL
        AND channel_type = 'Channel::FacebookPage'
        AND channel_id IN (
          SELECT id FROM channel_facebook_pages
          WHERE instagram_id IS NOT NULL AND instagram_id != ''
        );
    SQL

    # Channel::FacebookPage without instagram_id → 'facebook'
    execute <<~SQL
      UPDATE inboxes
      SET integration_slot = 'facebook'
      WHERE managed_company_id IS NOT NULL
        AND channel_type = 'Channel::FacebookPage'
        AND channel_id IN (
          SELECT id FROM channel_facebook_pages
          WHERE instagram_id IS NULL OR instagram_id = ''
        );
    SQL

    # Channel::Api with provider_type = 'linkedin' → 'linkedin'
    execute <<~SQL
      UPDATE inboxes
      SET integration_slot = 'linkedin'
      WHERE managed_company_id IS NOT NULL
        AND channel_type = 'Channel::Api'
        AND channel_id IN (
          SELECT id FROM channel_api
          WHERE additional_attributes->>'provider_type' = 'linkedin'
        );
    SQL
  end

  def down
    execute <<~SQL
      UPDATE inboxes SET integration_slot = NULL WHERE managed_company_id IS NOT NULL;
    SQL
  end
end
