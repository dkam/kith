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
end
