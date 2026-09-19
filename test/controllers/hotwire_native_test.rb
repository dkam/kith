require "test_helper"

class HotwireNativeTest < ActionDispatch::IntegrationTest
  setup { sign_in_as members(:alice) }

  test "the app is not turned away as an old browser" do
    get root_url, headers: native_headers
    assert_response :success

    get root_url, headers: native_headers(ANDROID_USER_AGENT)
    assert_response :success
  end

  test "an old browser without the app around it is still turned away" do
    get root_url, headers: native_headers(STALE_BROWSER_USER_AGENT)
    assert_response :not_acceptable
  end

  # Asked of the controller rather than of `request`: an integration test
  # rebuilds its `request` from the Rack env after the fact, and a variant
  # lives on the Request object rather than in the env.
  test "the app asks for the hotwire_native variant" do
    get root_url, headers: native_headers
    assert_equal [ :hotwire_native ], @controller.request.variant

    get root_url
    assert_empty @controller.request.variant
  end

  test "the app draws its own navigation, so the masthead goes" do
    get root_url, headers: native_headers
    assert_select "header", false
    assert_select "a[href=?]", settings_path, false

    get root_url
    assert_select "header a[href=?]", settings_path
  end

  test "the app is offered neither the manifest nor the service worker" do
    get root_url, headers: native_headers
    assert_select "link[rel=manifest]", false
    assert_no_match %r{import "pwa"}, response.body
    assert_no_match %r{modulepreload[^>]+/pwa-}, response.body

    get root_url
    assert_select "link[rel=manifest]"
    assert_match %r{import "pwa"}, response.body
  end

  test "the safe areas are paid once" do
    get root_url, headers: native_headers
    assert_select "main.pb-safe", false
    assert_select "main.pb-10"

    get root_url
    assert_select "main.pb-safe"
  end

  # The variant layout is a second rendering path, and a second rendering path
  # is where a privacy rule goes to be forgotten. It renders the same templates
  # through the same Visibility; these say so out loud.
  test "the app is shown exactly what the web is shown" do
    sign_out
    sign_in_as members(:dave)

    get profile_url("carol"), headers: native_headers
    assert_response :not_found

    get profile_url("nobody"), headers: native_headers
    assert_equal :not_found, Rack::Utils::SYMBOL_TO_STATUS_CODE.key(response.status)

    get post_url(posts(:carol_followers)), headers: native_headers
    assert_response :not_found

    get root_url, headers: native_headers
    assert_select "##{ActionView::RecordIdentifier.dom_id(posts(:carol_followers))}", false
  end
end
