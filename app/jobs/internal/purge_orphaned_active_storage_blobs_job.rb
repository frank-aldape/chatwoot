# housekeeping
# purge ActiveStorage blobs that were uploaded (e.g. via direct upload) but
# never attached to a record, or whose attached record was later destroyed
# without purging the blob. Only targets blobs older than the grace period so
# in-flight uploads aren't purged mid-request.

class Internal::PurgeOrphanedActiveStorageBlobsJob < ApplicationJob
  queue_as :housekeeping

  GRACE_PERIOD = 48.hours

  def perform
    # `unattached` LEFT JOINs active_storage_attachments, which also has a
    # created_at, so the column has to be qualified or Postgres rejects the query.
    ActiveStorage::Blob.unattached.where('active_storage_blobs.created_at < ?', GRACE_PERIOD.ago).find_each(&:purge_later)
  end
end
