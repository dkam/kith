# Direct upload puts a file in storage before the form that claims it is
# submitted, so a member who uploads and walks away leaves the file behind,
# attached to nothing. For a Strava export that is their whole account. For a
# photo dropped into the composer and never posted, it is a photo nobody chose
# to share. This sweeps both, and every other kind: any blob attached to
# nothing for a day.
#
# It also fails any StravaImport that stalled — a process that died between
# queued and the job's ensure — and purges its zip, so that neither the file
# nor the one-import-at-a-time rule outlives it.
class PurgeUnattachedBlobsJob < ApplicationJob
  queue_as :default

  AFTER = 1.day

  def perform
    StravaImport.stalled.find_each do |import|
      import.fail!(StravaImport::Stalled.new)
      import.export.purge
    end

    ActiveStorage::Blob.unattached.where(created_at: ...AFTER.ago).find_each(&:purge)
  end
end
