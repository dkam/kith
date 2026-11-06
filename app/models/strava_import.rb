# A member's Strava export, imported from the settings page: StravaExport, run
# in StravaImportJob, with the outcome kept here for the page to show.
#
# The zip is the whole account — logins, messages, device ids, followers and
# privacy zones with street addresses in them — so it is attached only for as
# long as the job needs it, and purged when the job ends, whatever the outcome.
# An upload that never reaches a job is purged by PurgeUnattachedBlobsJob.
#
# `result` holds what StravaExport::Result holds — counts, and the failed
# activities' ids and exception classes — or a refusal's message, which names
# a part of the file and never a value from it. Nothing else from the zip is
# ever written here, and its filename, which is Strava's, is never shown.
class StravaImport < ApplicationRecord
  # Checked on the blob, before anything is enqueued: direct upload puts the
  # zip in storage before the form arrives, so there is no form field to trust.
  MAX_BYTES = 2.gigabytes

  # An import left queued or running this long is not running: its process
  # died without reaching the job's ensure. PurgeUnattachedBlobsJob fails it,
  # so a member is never locked out of importing for good.
  STALLED_AFTER = 1.day

  # What a stalled import is failed with: there is no exception to name.
  class Stalled < StandardError; end

  # Integer-backed and sparse, like posts.audience. The partial unique index
  # in the migration names 0 and 10: change them there too.
  enum :state, { queued: 0, running: 10, done: 20, refused: 30, failed: 40 }, validate: true

  UNFINISHED = %w[ queued running ].freeze

  ALREADY_RUNNING = "An import is already running. Wait for it to finish."

  belongs_to :member
  has_one_attached :export

  scope :newest_first, -> { order(created_at: :desc, id: :desc) }
  scope :unfinished, -> { where(state: UNFINISHED) }
  scope :stalled, -> { unfinished.where(updated_at: ...STALLED_AFTER.ago) }

  # The latest import is the only one the page shows, and one at a time means
  # the import that changed is the latest. On a change of state only: purging
  # the zip touches the record, and says nothing new.
  after_update_commit -> { broadcast_replace_to member, :strava_imports, target: "latest_strava_import" },
    if: :saved_change_to_state?

  validates :export, presence: { message: "is needed: choose the zip Strava sent you" }, on: :create
  validate :export_within_size, on: :create
  validate :one_at_a_time, on: :create

  def unfinished? = UNFINISHED.include?(state)

  def finish!(result)
    update!(state: :done, finished_at: Time.current, result: {
      "created" => result.created, "updated" => result.updated, "unchanged" => result.unchanged,
      "removed" => result.removed, "failed" => result.failed
    })
  end

  # Only a StravaExport::Refused carries a message fit to keep: it names a part
  # of the export, never a value from it. Anything else is a failure.
  def refuse!(error)
    raise ArgumentError, "only a StravaExport::Refused is a refusal" unless error.is_a?(StravaExport::Refused)

    update!(state: :refused, finished_at: Time.current, result: { "refused" => error.message })
  end

  # The class name and nothing else: a message can carry a coordinate.
  def fail!(error)
    update!(state: :failed, finished_at: Time.current, result: { "error" => error.class.name })
  end

  def failed_activity_ids = result.fetch("failed", []).map(&:first)

  private
    def export_within_size
      return unless export.attached? && export.blob.byte_size > MAX_BYTES

      errors.add :export, "is larger than #{MAX_BYTES / 1.gigabyte} GB, which no Strava export should be"
    end

    def one_at_a_time
      errors.add :base, ALREADY_RUNNING if member&.strava_imports&.unfinished&.exists?
    end
end
