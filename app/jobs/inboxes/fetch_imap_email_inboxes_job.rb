class Inboxes::FetchImapEmailInboxesJob < ApplicationJob
  queue_as :scheduled_jobs
  include BillingHelper

  # Slightly under the cron interval (config/schedule.yml runs this job every
  # 5 minutes) so a stuck/errored run doesn't suppress fetching forever.
  ENQUEUE_DEDUPE_TTL = 4.minutes

  def perform
    email_inboxes = Inbox.where(channel_type: 'Channel::Email')
    email_inboxes.find_each(batch_size: 100) do |inbox|
      next unless should_fetch_emails?(inbox)
      next unless claim_fetch_slot?(inbox)

      ::Inboxes::FetchImapEmailsJob.perform_later(inbox.channel)
    end
  end

  private

  def should_fetch_emails?(inbox)
    return false if inbox.account.suspended?
    return false unless inbox.channel.imap_enabled
    return false if inbox.channel.reauthorization_required?

    return true unless ChatwootApp.chatwoot_cloud?
    return false if default_plan?(inbox.account)

    true
  end

  # Avoids enqueueing a new FetchImapEmailsJob when one for this inbox is
  # already queued or currently running, so a slow queue can't pile up
  # duplicate work for the same inbox faster than workers can drain it.
  def claim_fetch_slot?(inbox)
    key = format(::Redis::Alfred::EMAIL_FETCH_ENQUEUE_MUTEX, inbox_id: inbox.id)
    Redis::Alfred.set(key, 1, nx: true, ex: ENQUEUE_DEDUPE_TTL.to_i)
  end
end
