class CreateTeamInboxesAndSearchIndexes < ActiveRecord::Migration[7.0]
  def up
    create_table :team_inboxes do |t|
      t.references :team, null: false, foreign_key: true
      t.references :inbox, null: false, foreign_key: true, type: :integer
      t.references :account, null: false, foreign_key: true, type: :integer

      t.timestamps
    end

    add_index :team_inboxes, [:team_id, :inbox_id], unique: true
    add_index :team_inboxes, [:account_id, :inbox_id]
    add_index :team_inboxes, [:account_id, :team_id]

    add_column :inbox_members, :access_type, :string, null: false, default: 'manual'

    add_column :conversations, :contact_search_text, :text
    add_column :conversations, :custom_attributes_search_text, :text
    add_column :conversations, :search_vector, :tsvector

    add_column :messages, :contact_search_text, :text
    add_column :messages, :conversation_custom_attributes_search_text, :text
    add_column :messages, :search_vector, :tsvector

    add_index :conversations, :search_vector, using: :gin
    add_index :messages, :search_vector, using: :gin

    create_search_functions
    create_search_triggers
    backfill_search_columns
  end

  def down
    drop_search_triggers
    drop_search_functions

    remove_index :messages, :search_vector
    remove_index :conversations, :search_vector

    remove_column :messages, :search_vector
    remove_column :messages, :conversation_custom_attributes_search_text
    remove_column :messages, :contact_search_text

    remove_column :conversations, :search_vector
    remove_column :conversations, :custom_attributes_search_text
    remove_column :conversations, :contact_search_text

    remove_column :inbox_members, :access_type

    remove_index :team_inboxes, [:account_id, :team_id]
    remove_index :team_inboxes, [:account_id, :inbox_id]
    remove_index :team_inboxes, [:team_id, :inbox_id]
    drop_table :team_inboxes
  end

  private

  def create_search_functions
    execute <<~SQL
      CREATE OR REPLACE FUNCTION refresh_conversations_search_vector()
      RETURNS trigger
      LANGUAGE plpgsql
      AS $$
      BEGIN
        NEW.contact_search_text := COALESCE((
          SELECT trim(regexp_replace(concat_ws(' ',
            contacts.name,
            contacts.email,
            contacts.phone_number,
            contacts.identifier,
            contacts.additional_attributes::text,
            contacts.custom_attributes::text
          ), '\\s+', ' ', 'g'))
          FROM contacts
          WHERE contacts.id = NEW.contact_id
        ), '');

        NEW.custom_attributes_search_text := trim(
          regexp_replace(COALESCE(NEW.custom_attributes::text, ''), '\\s+', ' ', 'g')
        );

        NEW.search_vector :=
          setweight(to_tsvector('simple', COALESCE(NEW.contact_search_text, '')), 'A') ||
          setweight(to_tsvector('simple', COALESCE(NEW.custom_attributes_search_text, '')), 'B') ||
          setweight(to_tsvector('simple', COALESCE(NEW.cached_label_list, '')), 'C') ||
          setweight(to_tsvector('simple', COALESCE(NEW.identifier, '')), 'D');

        RETURN NEW;
      END;
      $$;
    SQL

    execute <<~SQL
      CREATE OR REPLACE FUNCTION sync_conversation_search_fields_to_messages()
      RETURNS trigger
      LANGUAGE plpgsql
      AS $$
      BEGIN
        UPDATE messages
        SET contact_search_text = NEW.contact_search_text,
            conversation_custom_attributes_search_text = NEW.custom_attributes_search_text
        WHERE conversation_id = NEW.id;

        RETURN NEW;
      END;
      $$;
    SQL

    execute <<~SQL
      CREATE OR REPLACE FUNCTION refresh_messages_search_vector()
      RETURNS trigger
      LANGUAGE plpgsql
      AS $$
      BEGIN
        NEW.contact_search_text := COALESCE((
          SELECT conversations.contact_search_text
          FROM conversations
          WHERE conversations.id = NEW.conversation_id
        ), COALESCE(NEW.contact_search_text, ''));

        NEW.conversation_custom_attributes_search_text := COALESCE((
          SELECT conversations.custom_attributes_search_text
          FROM conversations
          WHERE conversations.id = NEW.conversation_id
        ), COALESCE(NEW.conversation_custom_attributes_search_text, ''));

        NEW.search_vector :=
          setweight(to_tsvector('simple', COALESCE(NEW.content, '')), 'A') ||
          setweight(to_tsvector('simple', COALESCE(NEW.processed_message_content, '')), 'A') ||
          setweight(to_tsvector('simple', COALESCE(NEW.contact_search_text, '')), 'B') ||
          setweight(
            to_tsvector('simple', COALESCE(NEW.conversation_custom_attributes_search_text, '')),
            'C'
          ) ||
          setweight(to_tsvector('simple', COALESCE(NEW.content_attributes::text, '')), 'D');

        RETURN NEW;
      END;
      $$;
    SQL

    execute <<~SQL
      CREATE OR REPLACE FUNCTION sync_contact_search_fields()
      RETURNS trigger
      LANGUAGE plpgsql
      AS $$
      BEGIN
        UPDATE conversations
        SET contact_id = conversations.contact_id
        WHERE contact_id = NEW.id;

        RETURN NEW;
      END;
      $$;
    SQL
  end

  def create_search_triggers
    execute <<~SQL
      CREATE TRIGGER conversations_search_vector_before_write
      BEFORE INSERT OR UPDATE OF contact_id, custom_attributes, cached_label_list, identifier
      ON conversations
      FOR EACH ROW
      EXECUTE FUNCTION refresh_conversations_search_vector();
    SQL

    execute <<~SQL
      CREATE TRIGGER conversations_search_vector_after_write
      AFTER INSERT OR UPDATE OF contact_id, custom_attributes, cached_label_list, identifier
      ON conversations
      FOR EACH ROW
      EXECUTE FUNCTION sync_conversation_search_fields_to_messages();
    SQL

    execute <<~SQL
      CREATE TRIGGER messages_search_vector_before_write
      BEFORE INSERT OR UPDATE OF content, processed_message_content, content_attributes, conversation_id,
      contact_search_text, conversation_custom_attributes_search_text
      ON messages
      FOR EACH ROW
      EXECUTE FUNCTION refresh_messages_search_vector();
    SQL

    execute <<~SQL
      CREATE TRIGGER contacts_search_sync_after_write
      AFTER INSERT OR UPDATE OF name, email, phone_number, identifier, additional_attributes, custom_attributes
      ON contacts
      FOR EACH ROW
      EXECUTE FUNCTION sync_contact_search_fields();
    SQL
  end

  def drop_search_triggers
    execute 'DROP TRIGGER IF EXISTS contacts_search_sync_after_write ON contacts;'
    execute 'DROP TRIGGER IF EXISTS messages_search_vector_before_write ON messages;'
    execute 'DROP TRIGGER IF EXISTS conversations_search_vector_after_write ON conversations;'
    execute 'DROP TRIGGER IF EXISTS conversations_search_vector_before_write ON conversations;'
  end

  def drop_search_functions
    execute 'DROP FUNCTION IF EXISTS sync_contact_search_fields();'
    execute 'DROP FUNCTION IF EXISTS refresh_messages_search_vector();'
    execute 'DROP FUNCTION IF EXISTS sync_conversation_search_fields_to_messages();'
    execute 'DROP FUNCTION IF EXISTS refresh_conversations_search_vector();'
  end

  def backfill_search_columns
    execute <<~SQL
      UPDATE conversations
      SET contact_search_text = COALESCE(contact_lookup.search_text, ''),
          custom_attributes_search_text = trim(
            regexp_replace(COALESCE(conversations.custom_attributes::text, ''), '\\s+', ' ', 'g')
          )
      FROM (
        SELECT contacts.id,
               trim(regexp_replace(concat_ws(' ',
                 contacts.name,
                 contacts.email,
                 contacts.phone_number,
                 contacts.identifier,
                 contacts.additional_attributes::text,
                 contacts.custom_attributes::text
               ), '\\s+', ' ', 'g')) AS search_text
        FROM contacts
      ) AS contact_lookup
      WHERE conversations.contact_id = contact_lookup.id;
    SQL

    execute <<~SQL
      UPDATE conversations
      SET search_vector =
        setweight(to_tsvector('simple', COALESCE(contact_search_text, '')), 'A') ||
        setweight(to_tsvector('simple', COALESCE(custom_attributes_search_text, '')), 'B') ||
        setweight(to_tsvector('simple', COALESCE(cached_label_list, '')), 'C') ||
        setweight(to_tsvector('simple', COALESCE(identifier, '')), 'D');
    SQL

    execute <<~SQL
      UPDATE messages
      SET contact_search_text = COALESCE(conversations.contact_search_text, ''),
          conversation_custom_attributes_search_text = COALESCE(conversations.custom_attributes_search_text, '')
      FROM conversations
      WHERE messages.conversation_id = conversations.id;
    SQL

    execute <<~SQL
      UPDATE messages
      SET search_vector =
        setweight(to_tsvector('simple', COALESCE(content, '')), 'A') ||
        setweight(to_tsvector('simple', COALESCE(processed_message_content, '')), 'A') ||
        setweight(to_tsvector('simple', COALESCE(contact_search_text, '')), 'B') ||
        setweight(
          to_tsvector('simple', COALESCE(conversation_custom_attributes_search_text, '')),
          'C'
        ) ||
        setweight(to_tsvector('simple', COALESCE(content_attributes::text, '')), 'D');
    SQL
  end
end
