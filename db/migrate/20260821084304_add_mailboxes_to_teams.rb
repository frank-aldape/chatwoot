class AddMailboxesToTeams < ActiveRecord::Migration[7.0]
  # No index on purpose: an account has a handful of teams, so Postgres seq-scans
  # this table regardless and an index would only cost writes.
  def change
    add_column :teams, :mailboxes, :text, array: true, default: [], null: false
  end
end
