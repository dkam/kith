module HotwireNativeTestHelper
  # The hostile one, on purpose. A WKWebView's own user agent carries no
  # `Version/` token, so the suffix Hotwire Native appends is what `useragent`
  # reads as the Safari version — and this shape parses as Safari 1.0, which is
  # every screen in the app turning into a 406. Testing with a friendlier string
  # would test a failure we do not have.
  IOS_USER_AGENT = "Mozilla/5.0 (iPhone; CPU iPhone OS 18_0 like Mac OS X) " \
    "AppleWebKit/605.1.15 (KHTML, like Gecko) Mobile/15E148 " \
    "Hotwire Native iOS; Turbo Native iOS; bundle/1.0; version/1.0".freeze

  # An Android phone whose System WebView has not been updated in three years.
  # Chrome 108 is below `:modern`, so this one is blocked for a real reason —
  # which is exactly why the app has to be exempt from the question.
  ANDROID_USER_AGENT = "Mozilla/5.0 (Linux; Android 11; SM-A105F) " \
    "AppleWebKit/537.36 (KHTML, like Gecko) Version/4.0 Chrome/108.0.5359.128 " \
    "Mobile Safari/537.36 Hotwire Native Android".freeze

  # The same stale WebView without the app around it: still a browser, still
  # turned away.
  STALE_BROWSER_USER_AGENT = ANDROID_USER_AGENT.sub(" Hotwire Native Android", "").freeze

  def native_headers(user_agent = IOS_USER_AGENT)
    { "User-Agent" => user_agent }
  end
end

ActiveSupport.on_load(:action_dispatch_integration_test) do
  include HotwireNativeTestHelper
end
