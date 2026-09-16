require "test_helper"

class PostTest < ActiveSupport::TestCase
  test "a post defaults to the followers audience" do
    assert_equal "followers", Post.new.audience
  end

  # --- Drafts ---------------------------------------------------------------
  #
  # A draft is a post with no publication time. There is no second column and
  # no status enum: the timestamp is the whole fact, so nothing can be a draft
  # and published at once, or published with no date on it.

  test "a post starts as a draft" do
    post = actors(:alice).posts.create!(body: "Hello")

    assert post.draft?
    refute post.published?
    assert_nil post.published_at
  end

  test "publishing stamps the time" do
    post = actors(:alice).posts.create!(body: "Hello")

    assert post.publish!
    assert_in_delta Time.current, post.published_at, 5.seconds
    assert post.published?
  end

  test "publishing twice does not move the date" do
    post = published_post(actors(:alice), body: "Out already", published_at: 3.days.ago)

    refute post.publish!
    assert_in_delta 3.days.ago, post.reload.published_at, 5.seconds
  end

  test "live and drafts are the two halves of the table" do
    assert_equal Post.count, Post.live.count + Post.drafts.count
    assert_includes Post.drafts, posts(:alice_draft)
    assert_includes Post.live, posts(:alice_public)
  end

  test "a draft is not public, whatever its audience says" do
    refute posts(:alice_public_draft).leaves_the_instance?
    refute_includes Post.publicly_visible, posts(:alice_public_draft)
  end

  test "a draft's audience can still be changed: nobody has been promised anything" do
    draft = posts(:alice_draft)

    assert draft.update(audience: :public)
    assert draft.reload.audience_public?
  end

  test "publishing a draft can settle its audience in the same breath" do
    draft = posts(:alice_draft)

    assert draft.update(audience: :public, published_at: Time.current)
    assert draft.reload.audience_public?
  end

  test "an explicit published_at is kept" do
    when_ = 3.days.ago
    post = actors(:alice).posts.create!(body: "Backdated", published_at: when_)
    assert_in_delta when_, post.published_at, 1.second
  end

  test "the body is sanitised on the way to the page" do
    post = actors(:alice).posts.create!(body: "<p>A <strong>bold</strong> claim.</p><script>alert(1)</script>")

    assert_includes post.body.to_s, "<strong>bold</strong>"
    refute_includes post.body.to_s, "<script"
  end

  test "editing the body replaces it" do
    post = posts(:alice_followers)
    post.update!(body: "<p>Something else entirely</p>")

    assert_includes post.body.to_s, "Something else entirely"
    refute_includes post.body.to_s, "coast road"
  end

  test "a post must say something" do
    post = actors(:alice).posts.build

    refute post.valid?
    assert_includes post.errors[:base], "A post needs a title, something to say, or a photo."
  end

  test "a title alone is enough" do
    assert actors(:alice).posts.build(title: "Just a title").valid?
  end

  test "a photo alone is enough" do
    assert actors(:alice).posts.build(body: attachment_markup(photo_blob)).valid?
  end

  test "the audience is fixed at write time and cannot be changed" do
    post = posts(:alice_followers)

    post.audience = :public
    refute post.valid?
    assert_includes post.errors[:audience], "can't be changed after a post is written"

    assert posts(:alice_followers).reload.audience_followers?
  end

  test "everything else about a post can still be edited" do
    post = posts(:alice_followers)

    assert post.update(title: "A new title", body: "New words")
    assert_equal "A new title", post.reload.title
  end

  test "only published public posts leave the instance" do
    assert posts(:alice_public).leaves_the_instance?
    refute posts(:alice_followers).leaves_the_instance?
  end

  test "excerpt prefers the title and falls back to the body" do
    assert_equal "The long way round", posts(:alice_followers).excerpt
    assert_equal "No title on this one, just a thought.", posts(:bob_followers).excerpt
  end

  test "bodies and titles have limits" do
    refute actors(:alice).posts.build(body: "x" * (Post::BODY_LIMIT + 1)).valid?
    refute actors(:alice).posts.build(title: "x" * (Post::TITLE_LIMIT + 1), body: "ok").valid?
  end

  test "uris are unique so a federated post cannot arrive twice" do
    actors(:alice).posts.create!(body: "one", uri: "https://example.social/posts/1")

    assert_raises ActiveRecord::RecordNotUnique do
      actors(:bob).posts.create!(body: "two", uri: "https://example.social/posts/1")
    end
  end

  test "posts are local unless marked otherwise" do
    assert actors(:alice).posts.create!(body: "hi").local?
  end

  test "newest_first is strictly chronological" do
    assert_equal [ posts(:dave_followers), posts(:carol_followers), posts(:bob_followers), posts(:alice_public), posts(:alice_followers) ],
                 Post.live.newest_first.to_a
  end

  test "destroying an actor destroys their posts" do
    assert_difference -> { Post.count }, -4 do
      actors(:alice).destroy
    end
  end
end
