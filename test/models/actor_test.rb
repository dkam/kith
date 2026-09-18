require "test_helper"

class ActorTest < ActiveSupport::TestCase
  test "handles are normalised to lowercase and stripped of a leading @" do
    actor = LocalActor.create!(handle: "  @Zoe  ", display_name: "Zoe")
    assert_equal "zoe", actor.handle
  end

  test "handles must look like handles" do
    assert LocalActor.new(handle: "zoe_99").valid?
    refute LocalActor.new(handle: "zoe milne").valid?
    refute LocalActor.new(handle: "z").valid?
    refute LocalActor.new(handle: "zoe@example.com").valid?
    refute LocalActor.new(handle: "").valid?
  end

  test "two local actors cannot share a handle" do
    assert_raises ActiveRecord::RecordInvalid do
      LocalActor.create!(handle: "alice", display_name: "Impostor")
    end
  end

  test "a remote actor may share a handle with a local one" do
    remote = RemoteActor.create!(handle: "alice", domain: "example.social", inbox_url: "https://example.social/inbox")
    assert remote.persisted?
    assert_equal "alice@example.social", remote.full_handle
  end

  test "the database refuses duplicate local handles even without validation" do
    assert_raises ActiveRecord::RecordNotUnique do
      LocalActor.new(handle: "alice", display_name: "Impostor").save!(validate: false)
    end
  end

  test "local actors have no domain, remote actors must have one" do
    refute LocalActor.new(handle: "zoe", domain: "example.social").valid?
    refute RemoteActor.new(handle: "zoe", inbox_url: "https://example.social/inbox").valid?
  end

  test "local? follows the domain, not the class" do
    assert actors(:alice).local?
    refute RemoteActor.new(handle: "zoe", domain: "example.social").local?
  end

  test "full_handle omits the domain locally" do
    assert_equal "alice", actors(:alice).full_handle
  end

  test "to_s prefers the display name and falls back to the handle" do
    assert_equal "Alice Brennan", actors(:alice).to_s
    assert_equal "@zoe", LocalActor.new(handle: "zoe").to_s
  end

  test "discoverable is a ladder of four rungs and defaults to connections_only" do
    assert_equal "connections_only", LocalActor.new(handle: "zoe").discoverable
    assert_equal %w[ internet members connections_only invisible ], Actor.discoverables.keys
    assert_equal "anyone on the web", LocalActor.new(handle: "zoe", discoverable: :internet).discoverability

    refute LocalActor.new(handle: "zoe", discoverable: "nobody").valid?
  end

  test "private keys are encrypted at rest" do
    actor = LocalActor.create!(handle: "zoe", display_name: "Zoe", private_key: "-----BEGIN PRIVATE KEY-----")
    ciphertext = Actor.connection.select_value("SELECT private_key FROM actors WHERE id = #{actor.id}")

    refute_includes ciphertext, "BEGIN PRIVATE KEY"
    assert_equal "-----BEGIN PRIVATE KEY-----", actor.reload.private_key
  end

  test "destroying an actor destroys its member" do
    assert_difference -> { Member.count }, -1 do
      actors(:dave).destroy
    end
  end
end
