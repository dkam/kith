require "test_helper"

class StripMetadataJobTest < ActiveJob::TestCase
  test "the fixture really does carry GPS coordinates to begin with" do
    fields = Vips::Image.new_from_file(file_fixture("landscape.jpg").to_s).get_fields

    assert_includes fields, "exif-ifd3-GPSLatitude"
    assert_includes fields, "exif-ifd0-Make"
  end

  test "stripping removes every EXIF field from the original" do
    photo = embed_photo(posts(:alice_followers))

    StripMetadataJob.perform_now(photo)

    assert_empty exif_fields_of(photo.reload)
  end

  test "stripping preserves the image itself, rotated the right way up" do
    photo = embed_photo(posts(:alice_followers))

    StripMetadataJob.perform_now(photo)

    image = downloaded_image(photo.reload)
    # The fixture is 900x600 carrying an orientation flag of 6, so uprighting
    # it makes it 600x900. Stripping without rotating first would leave it on
    # its side forever.
    assert_equal 600, image.width
    assert_equal 900, image.height
  end

  # The body names each photograph by the blob's signed global id. Replacing
  # the blob with a stripped copy — rather than rewriting the one that is
  # there — would leave the post pointing at something that had been purged.
  test "the blob keeps its identity, so the body still points at it" do
    post = posts(:alice_followers)
    photo = embed_photo(post)
    blob_id = photo.blob_id

    StripMetadataJob.perform_now(photo)

    assert_equal blob_id, photo.reload.blob_id
    assert_equal [ blob_id ], post.reload.body.body.attachables.map(&:id)
  end

  test "embedding a photo enqueues the strip" do
    assert_enqueued_with job: StripMetadataJob do
      embed_photo(posts(:alice_followers))
    end
  end

  test "attaching an avatar enqueues the strip too" do
    assert_enqueued_with job: StripMetadataJob do
      actors(:alice).avatar.attach(io: file_fixture("portrait.jpg").open, filename: "portrait.jpg", content_type: "image/jpeg")
    end
  end

  test "a non-image attachment is left alone" do
    photo = embed_photo(posts(:alice_followers),
      io: StringIO.new("not an image"), filename: "notes.txt", content_type: "text/plain")
    checksum = photo.blob.checksum

    StripMetadataJob.perform_now(photo)

    assert_equal checksum, photo.blob.reload.checksum
  end

  test "a photo whose post was deleted while the job was queued is discarded quietly" do
    post = posts(:alice_followers)
    photo = embed_photo(post)
    post.destroy

    assert_nothing_raised do
      StripMetadataJob.perform_now(photo)
    end
  end

  test "variants carry no EXIF even before the job has run" do
    photo = embed_photo(posts(:alice_followers))
    variant = photo.variant(AttachableMedia.transformation_for(:feed)).processed

    assert_empty exif_fields_of(variant)
  end

  private
    def downloaded_image(attachment_or_variant)
      file = Tempfile.new([ "media", ".jpg" ], binmode: true)
      file.write attachment_or_variant.download
      file.flush
      Vips::Image.new_from_file(file.path)
    end

    def exif_fields_of(attachment_or_variant)
      downloaded_image(attachment_or_variant).get_fields.grep(/^exif-/)
    end
end
