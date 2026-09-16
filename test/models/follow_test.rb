require "test_helper"

class FollowTest < ActiveSupport::TestCase
  test "a new follow starts as requested" do
    follow = Follow.create!(follower_actor: actors(:bob), followed_actor: actors(:carol))

    assert follow.requested?
    assert_nil follow.accepted_at
  end

  test "accepting stamps the time" do
    follow = follows(:dave_follows_alice)
    follow.accept!

    assert follow.accepted?
    assert_in_delta Time.current, follow.accepted_at, 5.seconds
  end

  test "rejecting clears any accepted_at" do
    follow = follows(:alice_follows_carol)
    assert follow.accepted_at.present?

    follow.reject!

    assert follow.rejected?
    assert_nil follow.reload.accepted_at
  end

  test "accepting never creates the reverse edge" do
    follow = follows(:dave_follows_alice)

    assert_no_difference -> { Follow.count } do
      follow.accept!
    end

    assert_nil Follow.between(actors(:alice), actors(:dave)).first
  end

  test "an actor cannot follow itself" do
    follow = Follow.new(follower_actor: actors(:alice), followed_actor: actors(:alice))

    refute follow.valid?
    assert_includes follow.errors[:followed_actor], "can't be you"
  end

  test "there is only one edge per ordered pair" do
    duplicate = Follow.new(follower_actor: actors(:alice), followed_actor: actors(:bob))
    refute duplicate.valid?

    assert_raises ActiveRecord::RecordNotUnique do
      duplicate.save!(validate: false)
    end
  end

  test "the opposite direction is a separate edge" do
    assert follows(:alice_follows_bob).persisted?
    assert follows(:bob_follows_alice).persisted?
    refute_equal follows(:alice_follows_bob), follows(:bob_follows_alice)
  end

  test "requesting twice returns the existing edge" do
    existing = follows(:dave_follows_alice)

    assert_no_difference -> { Follow.count } do
      assert_equal existing, Follow.request(actors(:dave), actors(:alice))
    end
  end

  test "requesting does not quietly re-open a rejected follow" do
    rejected = follows(:carol_follows_dave)

    assert_equal rejected, Follow.request(actors(:carol), actors(:dave))
    assert rejected.reload.rejected?
  end

  test "a connection is mutual and accepted" do
    assert follows(:alice_follows_bob).connection?
    assert follows(:bob_follows_alice).connection?
  end

  test "a one-way follow is not a connection" do
    refute follows(:alice_follows_carol).connection?
  end

  test "a pending follow is not a connection even if the reverse is accepted" do
    refute follows(:dave_follows_alice).connection?
  end

  test "connected_to? is symmetric and derived" do
    assert actors(:alice).connected_to?(actors(:bob))
    assert actors(:bob).connected_to?(actors(:alice))

    refute actors(:alice).connected_to?(actors(:carol))
    refute actors(:carol).connected_to?(actors(:alice))
  end

  test "an actor is not connected to itself, or to nobody" do
    refute actors(:alice).connected_to?(actors(:alice))
    refute actors(:alice).connected_to?(nil)
  end

  test "follows? is one way and only counts accepted follows" do
    assert actors(:alice).follows?(actors(:carol))
    refute actors(:carol).follows?(actors(:alice))
    refute actors(:dave).follows?(actors(:alice))
    refute actors(:carol).follows?(actors(:dave))
  end

  test "visible_author_ids is yourself plus who you follow" do
    assert_equal [ actors(:alice), actors(:bob), actors(:carol) ].map(&:id).sort,
                 actors(:alice).visible_author_ids.sort

    assert_equal [ actors(:dave).id ], actors(:dave).visible_author_ids
  end

  test "destroying an actor destroys its follows in both directions" do
    assert_difference -> { Follow.count }, -4 do
      actors(:alice).destroy
    end
  end
end
