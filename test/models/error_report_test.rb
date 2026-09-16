require "test_helper"

# What may leave the instance when something breaks.
#
# Kith is a private network, so a crash report is an export. Three of its URLs
# carry a live credential in the path and one carries a person's name, and a
# stack trace arrives at Splat with the URL attached whether or not anybody
# thought about it. These tests are that thought.
class ErrorReportTest < ActiveSupport::TestCase
  # Whether anything is sent at all is ErrorReportingTest's question. This one
  # is only about what survives the trip.
  #
  # --- Credentials in the path ----------------------------------------------

  test "an invite code never leaves" do
    assert_scrubbed "/join/D5PKJ8A4QBWN", "/join/[filtered]"
  end

  test "a password reset token never leaves" do
    assert_scrubbed "/passwords/aGVsbG8gdGhlcmU/edit", "/passwords/[filtered]/edit"
    assert_scrubbed "/passwords/aGVsbG8gdGhlcmU", "/passwords/[filtered]"
  end

  test "asking for a password reset is not a token" do
    # /passwords/new is the form, not a credential — scrubbing it would throw
    # away which page broke for nothing.
    assert_unchanged "/passwords/new"
  end

  test "a signed attachment id never leaves" do
    # The signed id *is* the permission to read that photograph.
    assert_scrubbed "/media/eyJfcmFpbHMiOnsiZGF0YSI6MX19--abc/feed", "/media/[filtered]/feed"
    assert_scrubbed "/media/pending/eyJfcmFpbHMiOjF9--def/holiday.jpg", "/media/pending/[filtered]"
  end

  test "the variant survives, because it is not a secret and it is worth knowing" do
    assert_scrubbed "/media/anything--here/thumb", "/media/[filtered]/thumb"
  end

  # --- Names ----------------------------------------------------------------

  test "a handle names a person, so it goes too" do
    assert_scrubbed "/@alice", "/@[filtered]"
    assert_scrubbed "/actors/alice/follow", "/actors/[filtered]/follow"
  end

  # --- What is left ---------------------------------------------------------

  test "an ordinary path is left alone, or there is nothing to debug" do
    assert_unchanged "/"
    assert_unchanged "/posts/12"
    assert_unchanged "/posts/12/comments"
    assert_unchanged "/invites"
    assert_unchanged "/settings"
  end

  test "the scheme and host are kept" do
    assert_equal "https://kith.example.com/join/[filtered]",
      ErrorReport.scrub_url("https://kith.example.com/join/ABC123")
  end

  # --- Query strings --------------------------------------------------------

  test "a query string is filtered by the same rule the logs use" do
    assert_equal "page=2", ErrorReport.scrub_query("page=2")
    assert_equal "token=[FILTERED]", ErrorReport.scrub_query("token=sensitive")
    assert_equal "email=[FILTERED]", ErrorReport.scrub_query("email=alice%40example.com")
  end

  test "an empty query string stays empty rather than becoming one" do
    assert_nil ErrorReport.scrub_query(nil)
    assert_equal "", ErrorReport.scrub_query("")
  end

  # --- Who --------------------------------------------------------------------

  test "a member is a number, and nothing else" do
    # "Is this one person or is it everybody?" is the first question anybody
    # asks about an error. An integer answers it. A handle, a name or an email
    # address answers it no better and names somebody to a third party doing it.
    identity = ErrorReport.identity(members(:alice))

    assert_equal({ id: members(:alice).id }, identity)
    assert_equal [ :id ], identity.keys
  end

  test "a signed-out visitor is nobody" do
    assert_nil ErrorReport.identity(nil)
  end

  # --- Headers --------------------------------------------------------------

  test "a Referer carries a whole URL, so it is scrubbed like one" do
    # Referer is in neither of sentry-ruby's PII denylists, so it arrives
    # intact. Follow a link off /join/<code> and the code rides out in the
    # header of whatever breaks next.
    event = fake_event(headers: { "Referer" => "https://kith.example.com/join/ABC123" })

    ErrorReport.scrub(event)

    assert_equal "https://kith.example.com/join/[filtered]", event.request.headers["Referer"]
  end

  test "headers that are not a URL are left alone" do
    event = fake_event(headers: { "Accept" => "text/html", "Referer" => nil })

    ErrorReport.scrub(event)

    assert_equal "text/html", event.request.headers["Accept"]
  end

  # --- The event ------------------------------------------------------------

  test "scrubbing an event rewrites the request it carries" do
    event = fake_event(url: "https://kith.example.com/join/ABC123", query_string: "token=abc")

    assert_same event, ErrorReport.scrub(event)
    assert_equal "https://kith.example.com/join/[filtered]", event.request.url
    assert_equal "token=[FILTERED]", event.request.query_string
  end

  test "a query string sentry hands over as a hash is filtered too" do
    # sentry-ruby 7 hands query params over as a Hash, and leaves them off
    # entirely unless PII is switched on. Handle both rather than raise inside
    # before_send, which would take the whole reporter down with it.
    event = fake_event(query_string: { "page" => "2", "token" => "abc" })

    ErrorReport.scrub(event)

    assert_equal({ "page" => "2", "token" => "[FILTERED]" }, event.request.query_string)
  end

  test "an event with no request at all is passed through, not raised on" do
    # A job that fails carries no request. This used to be where a scrubber
    # that assumed one would take the reporter down with it.
    event = fake_event(request: nil)

    assert_same event, ErrorReport.scrub(event)
  end

  private
    def assert_scrubbed(path, expected)
      assert_equal "https://kith.example.com#{expected}",
        ErrorReport.scrub_url("https://kith.example.com#{path}")
    end

    def assert_unchanged(path)
      url = "https://kith.example.com#{path}"
      assert_equal url, ErrorReport.scrub_url(url), "#{path} holds no secret and no name"
    end

    FakeRequest = Struct.new(:url, :query_string, :headers)
    FakeEvent = Struct.new(:request)

    def fake_event(request: :build, url: "https://kith.example.com/", query_string: nil, headers: {})
      # A Struct double rather than a real Sentry event: building one needs an
      # initialized client, and the test above insists there never is one. The
      # accessors it stands in for are pinned by the test below.
      request = FakeRequest.new(url, query_string, headers) if request == :build
      FakeEvent.new(request)
    end
end

# The double above is only worth anything if the real interface still has the
# three accessors it imitates. sentry-ruby renaming one would otherwise leave a
# green suite and a before_send that silently stopped scrubbing.
class SentryRequestInterfaceTest < ActiveSupport::TestCase
  test "the request interface still carries a url, a query string and headers" do
    %i[ url url= query_string query_string= headers headers= ].each do |accessor|
      assert Sentry::RequestInterface.method_defined?(accessor),
        "Sentry::RequestInterface no longer responds to #{accessor} — ErrorReport.scrub needs rewriting"
    end
  end
end
