require "test_helper"

class StripMetadataJobTest < ActiveJob::TestCase
  test "the fixture really does carry GPS coordinates to begin with" do
    fields = Vips::Image.new_from_file(file_fixture("landscape.jpg").to_s).get_fields

    assert_includes fields, "exif-ifd3-GPSLatitude"
    assert_includes fields, "exif-ifd0-Make"
  end

  test "stripping removes every EXIF field from the original" do
    post = attach_landscape

    StripMetadataJob.perform_now(post.photos.first)

    assert_empty exif_fields_of(post.reload.photos.first)
  end

  test "stripping preserves the image itself, rotated the right way up" do
    post = attach_landscape

    StripMetadataJob.perform_now(post.photos.first)

    image = downloaded_image(post.reload.photos.first)
    # The fixture is 900x600 carrying an orientation flag of 6, so uprighting
    # it makes it 600x900. Stripping without rotating first would leave it on
    # its side forever.
    assert_equal 600, image.width
    assert_equal 900, image.height
  end

  test "attaching a photo enqueues the strip" do
    post = posts(:alice_followers)

    assert_enqueued_with job: StripMetadataJob do
      post.photos.attach(io: file_fixture("landscape.jpg").open, filename: "landscape.jpg", content_type: "image/jpeg")
    end
  end

  test "attaching an avatar enqueues the strip too" do
    assert_enqueued_with job: StripMetadataJob do
      actors(:alice).avatar.attach(io: file_fixture("portrait.jpg").open, filename: "portrait.jpg", content_type: "image/jpeg")
    end
  end

  test "a non-image attachment is left alone" do
    post = posts(:alice_followers)
    post.photos.attach(io: StringIO.new("not an image"), filename: "notes.txt", content_type: "text/plain")
    attachment = post.photos.first
    blob_id = attachment.blob_id

    StripMetadataJob.perform_now(attachment)

    assert_equal blob_id, attachment.reload.blob_id
  end

  test "a photo whose post was deleted while the job was queued is discarded quietly" do
    post = attach_landscape
    attachment = post.photos.first
    post.destroy

    assert_nothing_raised do
      StripMetadataJob.perform_now(attachment)
    end
  end

  test "variants carry no EXIF even before the job has run" do
    post = attach_landscape
    variant = post.photos.first.variant(AttachableMedia.transformation_for(:feed)).processed

    assert_empty exif_fields_of(variant)
  end

  private
    def attach_landscape
      posts(:alice_followers).tap do |post|
        post.photos.attach(io: file_fixture("landscape.jpg").open, filename: "landscape.jpg", content_type: "image/jpeg")
      end
    end

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
