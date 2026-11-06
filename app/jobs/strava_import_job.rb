# Runs one StravaImport: opens the uploaded zip as a tempfile, hands it to
# StravaExport, records what came of it, and purges the zip, whatever happened.
#
# The argument is the import's id and nothing else. A job's arguments are
# stored in the queue database, and a path or anything read from the zip
# would sit there after the zip itself was gone.
class StravaImportJob < ApplicationJob
  # What goes on to the error report, the queue's failed executions and the
  # job log in place of whatever was raised: its class and its backtrace, and
  # not its message, which can carry a name or a coordinate from the zip.
  class Failed < StandardError; end

  queue_as :default

  discard_on ActiveRecord::RecordNotFound

  def perform(import_id)
    import = StravaImport.find(import_id)
    run(import) if import.queued?
  end

  private
    def run(import)
      import.running!
      import.export.open do |file|
        import.finish! StravaExport.new(member: import.member, path: file.path).import
      end
    rescue StravaExport::Refused => e
      import.refuse!(e)
    rescue StandardError => e
      import.fail!(e)
      # cause: nil, or the original rides along as the cause, message and all.
      raise Failed, e.class.name, e.backtrace, cause: nil
    ensure
      import.export.purge
    end
end
