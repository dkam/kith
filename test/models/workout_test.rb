require "test_helper"

class WorkoutTest < ActiveSupport::TestCase
  def workout(**attributes)
    Workout.new(actor: actors(:alice), occurred_at: Time.utc(2026, 9, 19, 4, 23, 34),
      data: { "name" => "Morning ride", "activity_type" => "ride", "source_activity_type" => "Ride" }, **attributes)
  end

  def track(*lons) = Track.new([ lons.map { |lon| Track::Point.new(lon:, lat: -10.0, ele: nil, time: nil) } ])

  test "a workout is an entry, and starts as a draft for followers" do
    saved = workout.tap(&:save!)

    assert_kind_of Entry, saved
    assert_equal "Workout", saved.type
    assert saved.draft?
    assert saved.audience_followers?
    assert_includes actors(:alice).entries, saved
  end

  test "published is the timestamp, as it is for posts" do
    saved = workout(published_at: Time.current).tap(&:save!)

    assert saved.published?
    assert_equal [ saved ], Entry.live.to_a
    assert_empty Entry.drafts
  end

  test "an entry shares posts' audiences" do
    assert_equal Post.audiences, Entry.audiences
    refute workout(audience: "circle").valid?
  end

  test "an entry has to say when it happened" do
    refute workout(occurred_at: nil).valid?
  end

  test "a workout never links out" do
    refute workout(uri: "https://www.strava.com/activities/1").valid?
  end

  test "a workout's activity type is Kith's own" do
    Workout::ACTIVITY_TYPES.each { |type| assert workout.tap { _1.data["activity_type"] = type }.valid?, type }

    refute workout.tap { _1.data["activity_type"] = "Ride" }.valid?
    refute workout.tap { _1.data.delete("activity_type") }.valid?
  end

  test "data holds a workout's keys and nothing else" do
    sneaky = workout.tap { _1.data["Athlete Weight"] = "80.0" }

    refute sneaky.valid?
    assert_match "Athlete Weight", sneaky.errors[:data].first
    assert_no_match "80", sneaky.errors[:data].first, "an error names the key, never its value"
  end

  test "the full track is stored as GeoJSON, and reads back as the same track" do
    saved = workout.tap(&:save!)

    assert saved.full_track_from(track(-140.0, -139.999))
    saved.reload

    assert_equal "track.geojson", saved.full_track.filename.to_s
    assert_equal "application/geo+json", saved.full_track.content_type
    assert_equal track(-140.0, -139.999), saved.read_full_track
  end

  test "the same track again changes nothing and uploads nothing" do
    saved = workout.tap(&:save!)
    saved.full_track_from(track(-140.0, -139.999))

    assert_no_difference -> { ActiveStorage::Blob.count } do
      refute saved.reload.full_track_from(track(-140.0, -139.999))
    end
  end

  test "a different track replaces the old one" do
    saved = workout.tap(&:save!)
    saved.full_track_from(track(-140.0, -139.999))

    assert saved.reload.full_track_from(track(-140.0, -139.998))
    assert_equal track(-140.0, -139.998), saved.reload.read_full_track
  end

  test "an empty track stores nothing, and removes a track that was there" do
    saved = workout.tap(&:save!)
    refute saved.full_track_from(Track.new([]))
    assert saved.read_full_track.empty?

    saved.full_track_from(track(-140.0, -139.999))
    assert_difference -> { ActiveStorage::Blob.count }, -1 do
      assert saved.reload.full_track_from(Track.new([]))
    end
    refute saved.reload.full_track.attached?
  end

  test "destroying an actor destroys their entries" do
    saved = workout.tap(&:save!)
    actors(:alice).destroy

    refute Entry.exists?(saved.id)
  end
end
