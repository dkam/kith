# Every attachment in the app gets its metadata stripped, without each model
# having to remember to ask. See StripMetadataJob.
ActiveSupport.on_load(:active_storage_attachment) do
  after_create_commit { StripMetadataJob.perform_later(self) }
end
