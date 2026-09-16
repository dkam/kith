module PostTestHelper
  # Puts a photograph into a post's body the way the editor does: an uploaded
  # blob, named in the markup by its signed global id. Action Text turns that
  # into the embeds attachment that MediaController serves and Visibility
  # checks, so a test photo takes the same path a real one does.
  def embed_photo(post, url: nil, **blob_options)
    blob = photo_blob(**blob_options)

    post.update!(body: "#{post.body.body&.to_html}#{attachment_markup(blob, url: url)}")
    post.reload.photos.find { |attachment| attachment.blob_id == blob.id }
  end

  def photo_blob(filename: "landscape.jpg", content_type: "image/jpeg", io: nil)
    ActiveStorage::Blob.create_and_upload!(
      io: io || file_fixture(filename).open, filename: filename, content_type: content_type
    )
  end

  # `url` is what Lexxy sends: the Active Storage blob URL it drew the editor's
  # preview from. Post is supposed to drop it before storing.
  def attachment_markup(blob, url: nil)
    ActionText::Attachment.from_attachable(blob, presentation: "gallery", url: url).to_html
  end
end

ActiveSupport.on_load(:active_support_test_case) do
  include PostTestHelper
end
