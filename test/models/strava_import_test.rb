require "test_helper"

class StravaImportTest < ActiveSupport::TestCase
  setup { @member = members(:alice) }

  def blob = ActiveStorage::Blob.create_and_upload!(io: StringIO.new("PK"), filename: "export.zip")

  # Two form posts in the same instant both pass the validation; the index is
  # what stops the second.
  test "the database holds one unfinished import per member, whatever the model checks" do
    @member.strava_imports.create!(export: blob, state: :queued)

    assert_raises(ActiveRecord::RecordNotUnique) do
      @member.strava_imports.new(export: blob, state: :running).save(validate: false)
    end
  end

  test "finished imports do not count against the next one" do
    %i[ done refused failed ].each { |state| @member.strava_imports.create!(export: blob, state:) }

    assert @member.strava_imports.create(export: blob).persisted?
  end

  # Only a Refused carries a message written to be kept: it names a part of the
  # export. Any other exception's message may carry what was in it.
  test "only a StravaExport::Refused is kept as a refusal, message and all" do
    import = @member.strava_imports.create!(export: blob)

    assert_raises(ArgumentError) { import.refuse!(RuntimeError.new("51.5,-0.12")) }
    assert import.reload.queued?

    import.refuse!(StravaExport::Refused.new("no activities.csv in the export"))
    assert_equal({ "refused" => "no activities.csv in the export" }, import.reload.result)
  end

  test "a failure keeps the exception's class and nothing else" do
    import = @member.strava_imports.create!(export: blob)

    import.fail!(RuntimeError.new("51.5,-0.12"))

    assert_equal({ "error" => "RuntimeError" }, import.reload.result)
  end
end
