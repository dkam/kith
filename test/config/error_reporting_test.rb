# frozen_string_literal: true

require "test_helper"

# Whether anything leaves at all. ErrorReportTest covers what leaves once it
# does.
#
# Both tests here boot a second Rails process, because that is the only way to
# ask the question: whether Sentry starts is decided once, in an initializer,
# at boot, from the environment — and a boot with SENTRY_DSN set is a boot
# nothing else in this suite performs. The first version of this initializer
# read an autoloaded constant and raised `uninitialized constant ErrorReport`
# on exactly that boot and no other. A green suite said nothing about it.
class ErrorReportingTest < ActiveSupport::TestCase
  test "no DSN, no reporter" do
    refute Sentry.initialized?, "this suite runs with no SENTRY_DSN and must hold no client"
  end

  test "a DSN switches reporting on, and the app still boots" do
    assert_equal "initialized=true", boot("development", dsn: "https://public@splat.example.com/1")
  end

  test "the test environment never reports, however the environment is set" do
    assert_equal "initialized=false", boot("test", dsn: "https://public@splat.example.com/1")
  end

  # --- The scrubber is not optional -----------------------------------------

  test "nothing is sent that ErrorReport has not scrubbed" do
    source = Rails.root.join("config/initializers/sentry.rb").read

    # Both hooks, or the half that isn't routed becomes the way a URL gets out.
    assert_match(/config\.before_send\s*=.*ErrorReport\.scrub/, source)
    assert_match(/config\.before_send_transaction\s*=.*ErrorReport\.scrub/, source)
  end

  # Pinned by reading the source rather than by watching it happen: observing
  # it would mean a live Sentry client in the suite, which the first test here
  # forbids, and Minitest 6 ships no stub to fake one with. ErrorReport.identity
  # carries the rule and is tested properly; this only pins the wiring.
  test "a request that has a member says so, through ErrorReport" do
    source = Rails.root.join("app/controllers/application_controller.rb").read

    assert_match(/Sentry\.set_user\(ErrorReport\.identity\(current_member\)\)/, source)
    assert_match(/Sentry\.initialized\?/, source,
      "with no reporter running there is nobody to tell")
  end

  test "personal data stays here" do
    source = Rails.root.join("config/initializers/sentry.rb").read

    assert_match(/config\.send_default_pii\s*=\s*false/, source,
      "with PII on, the request body, the cookies and the caller's IP all go too")
  end

  private
    # A real boot, in a real environment, reporting one fact.
    def boot(env, dsn:)
      script = 'print "initialized=#{Sentry.initialized?}"'
      out = Bundler.with_unbundled_env do
        `cd #{Rails.root.to_s.shellescape} && RAILS_ENV=#{env} SENTRY_DSN=#{dsn.shellescape} bin/rails runner #{script.shellescape} 2>&1`
      end

      assert_predicate $?, :success?, "booting #{env} with a DSN failed:\n#{out}"
      out.strip
    end
end
