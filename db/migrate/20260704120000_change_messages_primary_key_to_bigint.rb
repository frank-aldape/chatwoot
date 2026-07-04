class ChangeMessagesPrimaryKeyToBigint < ActiveRecord::Migration[7.1]
  # messages.id was created as `serial` (int4), which overflows at ~2.1B rows.
  # Widening now, while the table is still small, avoids an expensive locked
  # rewrite later. change_column takes an ACCESS EXCLUSIVE lock and rewrites
  # the table — acceptable at the current size, run during low traffic.
  #
  # csat_survey_responses.message_id is already bigint; only attachments needs
  # the matching FK-column change.
  def up
    change_column :messages, :id, :bigint
    change_column :attachments, :message_id, :bigint

    # On Postgres 10+, `serial` creates an integer-typed sequence capped at
    # 2^31-1, and change_column does not touch it. Widen it so it can issue
    # values past the int4 ceiling.
    execute 'ALTER SEQUENCE messages_id_seq AS bigint'
  end

  def down
    execute 'ALTER SEQUENCE messages_id_seq AS integer'
    change_column :attachments, :message_id, :integer
    change_column :messages, :id, :integer
  end
end
