require "test_helper"

class CommentTest < ActiveSupport::TestCase
  test "a comment needs a body" do
    refute posts(:alice_followers).comments.build(actor: actors(:bob)).valid?
    refute posts(:alice_followers).comments.build(actor: actors(:bob), body: "   ").valid?
  end

  test "bodies have a limit" do
    refute posts(:alice_followers).comments.build(actor: actors(:bob), body: "x" * (Comment::BODY_LIMIT + 1)).valid?
  end

  test "comments are flat: there is nowhere to put a parent" do
    refute Comment.column_names.include?("parent_id")
    refute Comment.reflect_on_all_associations.map(&:name).include?(:parent)
  end

  test "comments read oldest first" do
    assert_equal [ comments(:carol_on_alice_followers), comments(:alice_on_alice_followers), comments(:bob_on_alice_followers) ].sort_by(&:created_at),
                 posts(:alice_followers).comments.to_a
  end

  test "bodies are not rendered as markup" do
    comment = posts(:alice_followers).comments.create!(actor: actors(:bob), body: "<b>hello</b>")
    assert_equal "<b>hello</b>", comment.body
    refute comment.respond_to?(:body_html)
  end

  test "deleting a post deletes its comments" do
    assert_difference -> { Comment.count }, -3 do
      posts(:alice_followers).destroy
    end
  end

  test "deleting an actor deletes their comments" do
    assert_difference -> { Comment.count }, -2 do
      actors(:carol).destroy
    end
  end
end
