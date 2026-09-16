require "test_helper"

# The privacy model. Every rule in here is a promise made to a member, so the
# coverage is deliberately exhaustive rather than representative.
#
# The fixture graph:
#
#   alice <-> bob        connected (mutual accepted follows)
#   alice  -> carol      one way; carol does not follow alice back
#   dave   -> alice      requested, not accepted
#   carol  -> dave       rejected
#
#   alice   discoverable: connections_only
#   bob     discoverable: everyone
#   carol   discoverable: invisible
#   dave    discoverable: connections_only
class VisibilityTest < ActiveSupport::TestCase
  # --- Posts ---------------------------------------------------------------

  test "an author always sees their own post" do
    assert as(:alice).post?(posts(:alice_followers))
  end

  test "an accepted follower sees a followers-only post" do
    assert as(:bob).post?(posts(:alice_followers))
  end

  test "a pending follower sees nothing" do
    refute as(:dave).post?(posts(:alice_followers))
  end

  test "a rejected follower sees nothing" do
    refute as(:carol).post?(posts(:dave_followers))
  end

  test "a stranger sees nothing" do
    refute as(:carol).post?(posts(:alice_followers))
  end

  test "following is one way: carol does not follow alice back" do
    assert as(:alice).post?(posts(:carol_followers))
    refute as(:carol).post?(posts(:alice_followers))
  end

  test "a signed-out visitor sees public posts and nothing else" do
    assert signed_out.post?(posts(:alice_public))
    refute signed_out.post?(posts(:alice_followers))
  end

  test "everyone signed in sees a public post, follower or not" do
    assert as(:dave).post?(posts(:alice_public))
    assert as(:carol).post?(posts(:alice_public))
  end

  test "a nil post is never visible" do
    refute as(:alice).post?(nil)
    refute signed_out.post?(nil)
  end

  test "revoking a follow revokes the posts with it" do
    assert as(:bob).post?(posts(:alice_followers))

    follows(:bob_follows_alice).reject!

    refute Visibility.new(actors(:bob).reload).post?(posts(:alice_followers))
  end

  # --- visible_posts must agree with post?, always --------------------------

  test "visible_posts agrees with post? for every actor and every post" do
    ([ nil ] + Actor.all.to_a).each do |viewer|
      policy = Visibility.new(viewer)
      queried = policy.visible_posts.pluck(:id).to_set

      Post.find_each do |post|
        assert_equal policy.post?(post), queried.include?(post.id),
          "visible_posts and post? disagree about #{post.title.inspect} for #{viewer&.handle || "a signed-out visitor"}"
      end
    end
  end

  test "visible_posts for a follower is their own posts plus those they follow, plus anything public" do
    assert_equal [ posts(:alice_followers), posts(:alice_public), posts(:bob_followers), posts(:carol_followers) ].map(&:id).sort,
                 as(:alice).visible_posts.pluck(:id).sort
  end

  test "visible_posts for someone who follows nobody is their own plus public" do
    assert_equal [ posts(:alice_public), posts(:dave_followers) ].map(&:id).sort,
                 as(:dave).visible_posts.pluck(:id).sort
  end

  test "visible_posts signed out is public only" do
    assert_equal [ posts(:alice_public).id ], signed_out.visible_posts.pluck(:id)
  end

  test "visible_posts narrows a scope rather than replacing it" do
    assert_equal [ posts(:bob_followers).id ], as(:alice).visible_posts(Post.by(actors(:bob))).pluck(:id)
  end

  # --- Profile links -------------------------------------------------------

  test "you can always link to yourself" do
    assert as(:carol).profile_link?(actors(:carol))
  end

  test "a discoverable-by-everyone member is always linked" do
    assert as(:dave).profile_link?(actors(:bob))
    assert as(:carol).profile_link?(actors(:bob))
  end

  test "a connections-only member is linked to their connections" do
    assert as(:bob).profile_link?(actors(:alice))
  end

  test "a connections-only member is not linked to a stranger" do
    refute as(:carol).profile_link?(actors(:alice))
    refute as(:dave).profile_link?(actors(:alice))
  end

  test "following someone one way does not earn you their profile link" do
    assert actors(:alice).follows?(actors(:carol))
    refute as(:alice).profile_link?(actors(:carol))
  end

  test "an invisible member is linked only to their connections" do
    refute as(:alice).profile_link?(actors(:carol))
    refute as(:bob).profile_link?(actors(:carol))
  end

  test "an invisible member who becomes connected is linked" do
    Follow.between(actors(:carol), actors(:alice)).first_or_create!(follower_actor: actors(:carol), followed_actor: actors(:alice)).accept!

    assert Visibility.new(actors(:alice).reload).profile_link?(actors(:carol))
  end

  test "a signed-out visitor gets no profile links at all, not even to the discoverable" do
    refute signed_out.profile_link?(actors(:bob))
    refute signed_out.profile_link?(actors(:alice))
  end

  test "a nil actor is never linked" do
    refute as(:alice).profile_link?(nil)
  end

  # --- Profile pages -------------------------------------------------------

  test "a connections-only profile page is open to any member, unlike its link" do
    refute as(:dave).profile_link?(actors(:alice))
    assert as(:dave).profile?(actors(:alice))
  end

  test "an invisible profile page is for connections only" do
    refute as(:alice).profile?(actors(:carol))
    assert as(:carol).profile?(actors(:carol))
  end

  test "signed-out visitors have no profile pages" do
    refute signed_out.profile?(actors(:bob))
  end

  # --- Comments ------------------------------------------------------------

  test "a comment is invisible when its post is" do
    refute as(:dave).comment?(comments(:bob_on_alice_followers))
    refute signed_out.comment?(comments(:bob_on_alice_followers))
  end

  test "a comment is visible when its post is" do
    assert as(:bob).comment?(comments(:bob_on_alice_followers))
    assert as(:alice).comment?(comments(:bob_on_alice_followers))
  end

  test "an invisible member's comment is hidden even on a post you can see" do
    assert as(:bob).post?(posts(:alice_followers))
    refute as(:bob).comment?(comments(:carol_on_alice_followers))
  end

  test "an invisible member's comment is hidden even on a public post" do
    assert signed_out.post?(posts(:alice_public))
    refute signed_out.comment?(comments(:carol_on_alice_public))
    refute as(:dave).comment?(comments(:carol_on_alice_public))
  end

  test "an invisible member sees their own comments" do
    assert as(:carol).comment?(comments(:carol_on_alice_public))
  end

  test "an invisible member's connections see their comments" do
    Follow.create!(follower_actor: actors(:carol), followed_actor: actors(:alice)).accept!

    assert Visibility.new(actors(:alice).reload).comment?(comments(:carol_on_alice_followers))
  end

  test "following an invisible member one way is not enough" do
    assert actors(:alice).follows?(actors(:carol))
    refute as(:alice).comment?(comments(:carol_on_alice_followers))
  end

  test "visible_comments agrees with comment? for every actor and every comment" do
    ([ nil ] + Actor.all.to_a).each do |viewer|
      policy = Visibility.new(viewer)

      Post.find_each do |post|
        queried = policy.visible_comments(post).pluck(:id).to_set

        post.comments.each do |comment|
          assert_equal policy.comment?(comment), queried.include?(comment.id),
            "visible_comments and comment? disagree about comment #{comment.id} for #{viewer&.handle || "a signed-out visitor"}"
        end
      end
    end
  end

  test "visible_comments on an invisible post is empty" do
    assert_empty as(:dave).visible_comments(posts(:alice_followers))
  end

  test "a nil comment is never visible" do
    refute as(:alice).comment?(nil)
  end

  # --- Media ---------------------------------------------------------------

  test "a photo is exactly as private as its post" do
    post = posts(:alice_followers)
    post.photos.attach(io: file_fixture("landscape.jpg").open, filename: "landscape.jpg", content_type: "image/jpeg")
    attachment = post.photos.first

    assert as(:alice).attachment?(attachment)
    assert as(:bob).attachment?(attachment)
    refute as(:dave).attachment?(attachment)
    refute signed_out.attachment?(attachment)
  end

  test "a photo on a public post is visible to anyone" do
    post = posts(:alice_public)
    post.photos.attach(io: file_fixture("landscape.jpg").open, filename: "landscape.jpg", content_type: "image/jpeg")

    assert signed_out.attachment?(post.photos.first)
  end

  test "an avatar is visible to any member but not to a signed-out visitor" do
    actors(:carol).avatar.attach(io: file_fixture("portrait.jpg").open, filename: "portrait.jpg", content_type: "image/jpeg")
    attachment = actors(:carol).avatar.attachment

    assert as(:dave).attachment?(attachment)
    refute signed_out.attachment?(attachment)
  end

  test "an attachment on anything else is refused" do
    refute as(:alice).attachment?(nil)
  end

  private
    def as(fixture_name)
      Visibility.new(actors(fixture_name))
    end

    def signed_out
      Visibility.new(nil)
    end
end
