require "test_helper"

class SourceTest < ActiveSupport::TestCase
  test "a member has one source of each kind" do
    members(:alice).sources.create!(kind: :strava_export)

    duplicate = members(:alice).sources.build(kind: :strava_export)
    refute duplicate.valid?
    assert members(:bob).sources.build(kind: :strava_export).valid?
  end

  test "an unknown kind is refused rather than raised" do
    refute members(:alice).sources.build(kind: "myspace").valid?
  end

  test "config defaults to empty" do
    assert_equal({}, members(:alice).sources.create!(kind: :strava_export).config)
  end

  test "losing a source leaves its entries with their actor" do
    source = members(:alice).sources.create!(kind: :strava_export)
    entry = Workout.create!(actor: actors(:alice), source:, external_id: "1", occurred_at: Time.current,
      data: { "activity_type" => "ride" })

    members(:alice).sources.destroy_all

    assert_nil entry.reload.source
    assert_equal actors(:alice), entry.actor
  end

  test "an activity id is unique within a source, not across them" do
    alice = members(:alice).sources.create!(kind: :strava_export)
    bob = members(:bob).sources.create!(kind: :strava_export)
    attributes = { external_id: "1", occurred_at: Time.current, data: { "activity_type" => "ride" } }

    Workout.create!(actor: actors(:alice), source: alice, **attributes)
    Workout.create!(actor: actors(:bob), source: bob, **attributes)

    assert_raises(ActiveRecord::RecordNotUnique) { Workout.create!(actor: actors(:alice), source: alice, **attributes) }
  end
end
