# Importing a member's own Strava export from settings. The zip arrives by
# direct upload, so the form carries only its blob's signed id; the import runs
# in StravaImportJob, and its result arrives on this page by Turbo Stream.
class StravaImportsController < ApplicationController
  def show
    @latest = current_member.strava_imports.newest_first.first
    @strava_import = StravaImport.new
  end

  # Whatever happens to the form, an upload it refuses is purged now rather
  # than left for the sweeper: it is the member's whole account.
  def create
    blob = uploaded_blob
    @strava_import = current_member.strava_imports.build(export: blob)

    if save_one_at_a_time
      StravaImportJob.perform_later(@strava_import.id)
      redirect_to settings_strava_import_path
    else
      blob&.purge
      @latest = current_member.strava_imports.newest_first.first
      render :show, status: :unprocessable_content
    end
  end

  private
    # Only a blob attached to nothing: one fresh from this form's upload. A
    # signed id that names a blob already attached somewhere — a photo in a
    # post, say — is no export, and the job would purge it at the end.
    def uploaded_blob
      signed_id = params.dig(:strava_import, :export)
      blob = ActiveStorage::Blob.find_signed(signed_id) if signed_id.is_a?(String)
      blob unless blob.nil? || blob.attachments.exists?
    end

    # The model checks for an import already running; the unique index catches
    # the second of two form posts that arrive together.
    def save_one_at_a_time
      @strava_import.save
    rescue ActiveRecord::RecordNotUnique
      @strava_import.errors.add :base, StravaImport::ALREADY_RUNNING
      false
    end
end
