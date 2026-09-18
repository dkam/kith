require "test_helper"

class McpControllerTest < ActionDispatch::IntegrationTest
  setup do
    # Materialise the fixture posts into everyone's feeds, as writing them
    # would have.
    Post.find_each { |post| FanOutJob.perform_now(post) }
    @token = mcp_tokens(:alice)
  end

  # --- The endpoint itself --------------------------------------------------

  test "a token in the query string is the whole of authentication" do
    assert_equal "kith", call("initialize", protocolVersion: "2025-06-18", capabilities: {}, clientInfo: { name: "test", version: "1" })
      .dig("result", "serverInfo", "name")
  end

  test "a bearer header is accepted too" do
    post mcp_url, params: rpc("tools/list").to_json,
      headers: { "CONTENT_TYPE" => "application/json", "Authorization" => "Bearer #{@token.token}" }

    assert_response :success
  end

  test "an unknown, missing or rotated token is not found — never forbidden" do
    post mcp_url(token: "nosuchtokenatall00000000"), params: rpc("tools/list").to_json, headers: json_headers
    assert_response :not_found

    post mcp_url, params: rpc("tools/list").to_json, headers: json_headers
    assert_response :not_found

    was = @token.token
    @token.rotate!
    post mcp_url(token: was), params: rpc("tools/list").to_json, headers: json_headers
    assert_response :not_found
  end

  test "a signed-in browser session does not open the endpoint" do
    sign_in_as members(:alice)

    post mcp_url, params: rpc("tools/list").to_json, headers: json_headers

    assert_response :not_found
  end

  test "using the endpoint records that it was used" do
    assert_nil @token.last_used_at

    call("tools/list")

    assert_not_nil @token.reload.last_used_at
  end

  test "a notification gets no reply" do
    post mcp_url(token: @token.token), params: { jsonrpc: "2.0", method: "notifications/initialized" }.to_json,
      headers: json_headers

    assert_response :accepted
    assert_empty response.body
  end

  test "GET is the stream Kith does not offer" do
    get mcp_url(token: @token.token)

    assert_response :method_not_allowed
  end

  # --- The tools ------------------------------------------------------------

  test "the endpoint offers four read-only tools" do
    tools = call("tools/list").dig("result", "tools")

    assert_equal %w[ whoami feed post notifications ].sort, tools.map { |tool| tool["name"] }.sort
    assert tools.all? { |tool| tool.dig("annotations", "readOnlyHint") }, "every tool says it only reads"
  end

  test "whoami answers about the token's member" do
    text = invoke("whoami")

    assert_includes text, "@alice"
    assert_includes text, "Alice Brennan"
    assert_includes text, "read only"
  end

  test "the feed is your own posts and those of people you follow" do
    text = invoke("feed")

    assert_includes text, posts(:alice_followers).title
    assert_includes text, posts(:carol_followers).title
    assert_not_includes text, posts(:dave_followers).title
  end

  test "the feed holds the same opinion as the feed page" do
    assert_includes invoke("feed"), posts(:bob_followers).excerpt

    follows(:bob_follows_alice).reject!
    follows(:alice_follows_bob).reject!

    assert_not_includes invoke("feed"), posts(:bob_followers).excerpt
  end

  test "unread_only leaves out what has been read" do
    FeedItem.find_by(member: members(:alice), post: posts(:carol_followers)).read!

    assert_not_includes invoke("feed", unread_only: true), posts(:carol_followers).title
    assert_includes invoke("feed", unread_only: false), posts(:carol_followers).title
  end

  test "a post you may see comes back whole" do
    posts(:alice_followers).update!(body: "<div>The coast road, then.</div>")

    text = invoke("post", id: posts(:alice_followers).id)

    assert_includes text, "The long way round"
    assert_includes text, "The coast road, then."
  end

  test "a post you may not see answers exactly as one that was never written" do
    hidden = invoke("post", id: posts(:dave_followers).id, expect_error: true)
    absent = invoke("post", id: 0, expect_error: true)

    assert_equal absent, hidden
  end

  test "comments come through the same gate as the post page" do
    text = invoke("post", id: posts(:alice_followers).id)

    assert_includes text, comments(:bob_on_alice_followers).body
    # Carol is invisible and Alice is not connected to her, so her comment is
    # not shown — the same answer the page gives.
    assert_not_includes text, comments(:carol_on_alice_followers).body
  end

  test "notifications pass the identical check as the feed" do
    Notification.create!(member: members(:alice), actor: actors(:bob),
      subject: comments(:bob_on_alice_followers), kind: :new_comment)
    Notification.create!(member: members(:alice), actor: actors(:carol),
      subject: comments(:carol_on_alice_followers), kind: :new_comment)

    text = invoke("notifications")

    assert_includes text, "Bob Ndlovu"
    # Carol is invisible and Alice isn't connected to her, so Carol's comment is
    # hidden on the post itself. Announcing it here would be the side channel
    # doing exactly what it is famous for.
    assert_not_includes text, "Carol Iyer"
  end

  test "a tool call is answered under its own member, not the last one" do
    assert_includes invoke("whoami"), "@alice"
    assert_includes invoke("whoami", token: mcp_tokens(:bob)), "@bob"
  end

  private
    def json_headers = { "CONTENT_TYPE" => "application/json" }

    def rpc(method, params = {})
      { jsonrpc: "2.0", id: 1, method: method, params: params }
    end

    def call(method, token: @token, **params)
      post mcp_url(token: token.token), params: rpc(method, params).to_json, headers: json_headers
      assert_response :success

      JSON.parse(response.body)
    end

    # The text one tool call comes back with.
    def invoke(name, token: @token, expect_error: false, **arguments)
      result = call("tools/call", token: token, name: name, arguments: arguments).fetch("result")

      assert_equal expect_error, result["isError"] == true, result.inspect
      result.fetch("content").map { |part| part["text"] }.join("\n")
    end
end
