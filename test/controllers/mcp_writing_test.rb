require "test_helper"

# What a read-and-write endpoint may do, and what it still may not.
class McpWritingTest < ActionDispatch::IntegrationTest
  setup do
    Post.find_each { |post| FanOutJob.perform_now(post) }
    @token = mcp_tokens(:alice_writer)
  end

  test "writing a post publishes it as the member" do
    assert_difference -> { Post.count }, 1 do
      invoke("write_post", title: "From the train", body: "Two fields and a tunnel.")
    end

    post = Post.order(:id).last
    assert_equal actors(:alice), post.actor
    assert_equal "From the train", post.title
    assert_includes post.body.to_plain_text, "Two fields and a tunnel."
  end

  test "a post written this way reaches followers unless it is asked to go further" do
    invoke("write_post", body: "Quietly.")
    assert_predicate Post.order(:id).last, :audience_followers?

    invoke("write_post", body: "Loudly.", audience: "public")
    assert_predicate Post.order(:id).last, :audience_public?
  end

  test "blank lines become paragraphs, and the text is the member's, not markup" do
    invoke("write_post", body: "First thought.\n\nSecond <b>thought</b>.")

    html = Post.order(:id).last.body.body.to_html
    assert_equal 2, html.scan("<p>").size
    assert_not_includes html, "<b>"
    assert_includes Post.order(:id).last.body.to_plain_text, "Second <b>thought</b>."
  end

  test "a post with nothing in it is refused, with the reason" do
    assert_no_difference -> { Post.count } do
      assert_includes invoke("write_post", body: "   ", expect_error: true), "needs a title"
    end
  end

  test "an audience that isn't one of the two is refused by the schema" do
    assert_no_difference -> { Post.count } do
      result = call("tools/call", name: "write_post", arguments: { body: "Somewhere else.", audience: "everyone" })

      assert result.dig("result", "isError"), result.inspect
    end
  end

  test "commenting works on a post you can see" do
    assert_difference -> { Comment.count }, 1 do
      invoke("comment", post_id: posts(:carol_followers).id, body: "Good to hear it.")
    end

    assert_equal actors(:alice), Comment.order(:id).last.actor
  end

  test "commenting on a post you may not see refuses as if it were never written" do
    hidden = invoke("comment", post_id: posts(:dave_followers).id, body: "Hello?", expect_error: true)
    absent = invoke("comment", post_id: 0, body: "Hello?", expect_error: true)

    assert_equal absent, hidden
    assert_not Comment.exists?(actor: actors(:alice), body: "Hello?")
  end

  test "an empty comment is refused" do
    assert_no_difference -> { Comment.count } do
      invoke("comment", post_id: posts(:alice_followers).id, body: "", expect_error: true)
    end
  end

  test "marking one post read clears only that one" do
    item = FeedItem.find_by(member: members(:alice), post: posts(:carol_followers))

    invoke("mark_read", post_id: posts(:carol_followers).id)

    assert_predicate item.reload, :read?
    assert_not_predicate FeedItem.find_by(member: members(:alice), post: posts(:bob_followers)), :read?
  end

  test "marking everything read clears the member's own feed and nobody else's" do
    invoke("mark_read", all: true)

    assert_empty members(:alice).feed_items.unread
    assert_not_empty members(:bob).feed_items.unread
  end

  test "marking a post that is not in your feed refuses" do
    invoke("mark_read", post_id: posts(:dave_followers).id, expect_error: true)
  end

  test "an endpoint writes as its own member" do
    invoke("write_post", body: "Mine.", token: mcp_tokens(:alice_writer))

    assert_equal actors(:alice), Post.order(:id).last.actor
  end

  private
    def rpc(method, params = {})
      { jsonrpc: "2.0", id: 1, method: method, params: params }
    end

    def call(method, token: @token, **params)
      post mcp_url(token: token.token), params: rpc(method, params).to_json,
        headers: { "CONTENT_TYPE" => "application/json" }
      assert_response :success

      JSON.parse(response.body)
    end

    def invoke(name, token: @token, expect_error: false, **arguments)
      result = call("tools/call", token: token, name: name, arguments: arguments).fetch("result")

      assert_equal expect_error, result["isError"] == true, result.inspect
      result.fetch("content").map { |part| part["text"] }.join("\n")
    end
end
