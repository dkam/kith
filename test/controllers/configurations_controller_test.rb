require "test_helper"

class ConfigurationsControllerTest < ActionDispatch::IntegrationTest
  PLATFORMS = %w[ ios_v1 android_v1 ].freeze

  test "a shell can fetch its rules before anybody has signed in" do
    PLATFORMS.each do |name|
      get hotwire_configuration_url(name)

      assert_response :success
      assert_equal "application/json", response.media_type
      assert configuration(name)["rules"].any?, "#{name} has no rules"
    end
  end

  # One of only two responses in Kith that may say `public`, and for the
  # documented reason: no session is consulted and every client gets the same
  # bytes.
  test "the rules are cacheable, because there is no session in them" do
    get hotwire_configuration_url("ios_v1")

    assert_match "public", response.headers["Cache-Control"]
  end

  test "a version nobody serves is a 404" do
    get "/configurations/ios_v2.json"
    assert_response :not_found

    get "/configurations/nonsense.json"
    assert_response :not_found
  end

  # The two files are edited separately and are certain to drift. When they do,
  # the symptom is an Android composer opening in the wrong container months
  # later — the same reason profile_link? and profile? are cross-checked.
  test "the two platforms agree about which paths are which" do
    assert_equal patterns_for("ios_v1"), patterns_for("android_v1")
  end

  test "every rule is a pattern Ruby can read" do
    PLATFORMS.each do |name|
      patterns_for(name).flatten.each do |pattern|
        assert_nothing_raised { Regexp.new(pattern) }
      end
    end
  end

  # A pattern that matches nothing is a rule that was renamed out from under
  # the app and nobody noticed. The paths here are the ones the rules exist
  # for, named through the router so a route change breaks this rather than a
  # phone.
  test "the rules point at paths this Kith actually serves" do
    {
      new_post_path => "modal",
      edit_post_path(posts(:alice_public)) => "modal",
      settings_path => "modal",
      invites_path => "modal",
      new_session_path => "replace",
      media_path("signed", "full") => "modal"
    }.each do |path, expectation|
      rule = matching_rule("ios_v1", path)
      assert rule, "no rule matches #{path}"
      assert_equal expectation, rule["properties"]["context"] || rule["properties"]["presentation"],
        "#{path} is not #{expectation}"
    end
  end

  private
    def configuration(name)
      get hotwire_configuration_url(name)
      JSON.parse(response.body)
    end

    def patterns_for(name)
      configuration(name)["rules"].map { |rule| rule["patterns"] }
    end

    # Later rules win, so the last match is the one that decides.
    def matching_rule(name, path)
      configuration(name)["rules"].reverse.find do |rule|
        rule["patterns"].any? { |pattern| Regexp.new(pattern).match?(path) } &&
          rule["patterns"] != [ ".*" ]
      end
    end
end
