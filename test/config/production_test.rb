# frozen_string_literal: true

require "test_helper"

# What the deployed app is configured to do, asked of a real production boot —
# the only way to ask it. These settings live in an environment file that this
# suite never loads, so every one of them is a thing that can be wrong for
# months with a green suite behind it. The password reset is the cautionary
# tale: `host: "example.com"` ships as a generated default, and the failure it
# produces is an email that arrives, looks right, and goes nowhere.
class ProductionTest < ActiveSupport::TestCase
  HOST = "kith.example.org"

  test "a password reset link points at this Kith, over https" do
    assert_equal "https://#{HOST}/passwords/abc/edit",
      boot('print Rails.application.routes.url_helpers.edit_password_url("abc", **Rails.application.config.action_mailer.default_url_options)',
        KITH_HOST: HOST)
  end

  test "a Kith that does not know its own address refuses to start" do
    output, ok = run_boot('print "booted"')

    refute ok, "production booted with no KITH_HOST, and will send links to somewhere that is not us"
    assert_match(/KITH_HOST/, output, "the refusal has to say which variable to set")
  end

  test "the image build is the one boot with no host, and it is allowed" do
    # `SECRET_KEY_BASE_DUMMY=1 ./bin/rails assets:precompile` boots production
    # inside the Dockerfile, where no host exists and nothing is served.
    assert_equal "booted", boot('print "booted"', SECRET_KEY_BASE_DUMMY: "1")
  end

  test "behind a TLS-terminating proxy: secure cookies, and no redirect loop on /up" do
    facts = boot(<<~RUBY.squish, KITH_HOST: HOST)
      request = ActionDispatch::Request.new("PATH_INFO" => "/up");
      print [ Rails.application.config.assume_ssl,
              Rails.application.config.force_ssl,
              Rails.application.config.ssl_options.dig(:redirect, :exclude)&.call(request) ].inspect
    RUBY

    # assume_ssl: the proxy speaks http to us, so without it every cookie is set
    # unsecured and a form POST can 422 on the CSRF origin check.
    # force_ssl: HSTS and secure cookies. The exclusion keeps the container's
    # own health check off the redirect, which it would otherwise follow to a
    # hostname it cannot resolve.
    assert_equal "[true, true, true]", facts
  end

  test "only this host is answered, and the health check whatever the Host says" do
    facts = boot(<<~RUBY.squish, KITH_HOST: HOST)
      request = ActionDispatch::Request.new("PATH_INFO" => "/up");
      print [ Rails.application.config.hosts.include?("#{HOST}"),
              Rails.application.config.host_authorization[:exclude]&.call(request) ].inspect
    RUBY

    assert_equal "[true, true]", facts
  end

  test "the SMTP relay comes from the environment" do
    settings = boot("print Rails.application.config.action_mailer.smtp_settings.inspect",
      KITH_HOST: HOST, SMTP_ADDRESS: "smtp.fastmail.com", SMTP_PORT: "465", SMTP_USER_NAME: "kith@example.org", SMTP_PASSWORD: "hunter2")

    assert_match(/address: "smtp\.fastmail\.com"/, settings)
    assert_match(/port: 465/, settings)
    assert_match(/user_name: "kith@example\.org"/, settings)
    assert_match(/authentication: :plain/, settings)
  end

  test "an SMTP server that was never filled in is not a blank one" do
    # `SMTP_ADDRESS: ${SMTP_ADDRESS:-}` in compose.yml hands the container an
    # empty string rather than no variable at all, and ENV.fetch takes an empty
    # string for an answer. Left alone, that is a relay at "" on port 0.
    settings = boot("print Rails.application.config.action_mailer.smtp_settings.inspect",
      KITH_HOST: HOST, SMTP_ADDRESS: "", SMTP_PORT: "", SMTP_USER_NAME: "")

    assert_match(/address: "localhost"/, settings)
    assert_match(/port: 587/, settings)
    refute_match(/authentication/, settings, "no user name is not a user name of \"\"")
  end

  private
    # Every name production reads, so that a variable set in the shell this
    # suite was started from cannot answer for one the test meant to leave out.
    THEIRS = %w[ KITH_HOST KITH_MAIL_FROM SMTP_ADDRESS SMTP_PORT SMTP_USER_NAME SMTP_PASSWORD SECRET_KEY_BASE_DUMMY ]

    def boot(script, **environment)
      output, ok = run_boot(script, **environment)
      assert ok, "production would not boot:\n#{output}"
      output
    end

    def run_boot(script, **environment)
      environment = { RAILS_ENV: "production", RAILS_LOG_LEVEL: "fatal", SECRET_KEY_BASE: "0" * 128 }.merge(environment)
      assignments = environment.map { |name, value| "#{name}=#{value.shellescape}" }
      unset = (THEIRS - environment.keys.map(&:to_s)).map { |name| "-u #{name}" }

      output = Bundler.with_unbundled_env do
        `cd #{Rails.root.to_s.shellescape} && env #{unset.join(" ")} #{assignments.join(" ")} bin/rails runner #{script.shellescape} 2>&1`
      end

      [ output.strip, $?.success? ]
    end
end
