# Optional error reporting, and off unless somebody asks for it: no SENTRY_DSN,
# no client, no network, nothing to configure.
#
# The DSN points at a Splat instance — ours is splat.apps.aapamilne.com — which
# speaks the Sentry protocol. Create a project there, copy its External DSN,
# and give it to the container as SENTRY_DSN.
#
# What is allowed to leave the instance is not decided here. ErrorReport
# decides, and it is the only thing that does — named below only inside the
# callbacks, which run long after boot. An initializer cannot reach an
# autoloaded constant, and `if ErrorReport.enabled?` here raised
# `uninitialized constant ErrorReport` on every boot, with or without a DSN.
#
# Never in test. A suite that reports is a suite that tells a third party what
# its fixtures are called, and CI is exactly where a stray DSN turns up.
if ENV["SENTRY_DSN"].present? && !Rails.env.test?
  Sentry.init do |config|
    config.dsn = ENV["SENTRY_DSN"]

    # The two halves of "what is running?", from config/version.rb: the release
    # somebody named, and the commit it was built from.
    config.environment = Rails.env
    config.release = Kith::VERSION

    # No personal data, which here is the difference between a bug report and a
    # leak. Off, this also switches off the request body, the cookies, the
    # caller's IP, SQL bind values and the query string — see ErrorReport for
    # the two things it does *not* cover.
    config.send_default_pii = false

    # Breadcrumbs from Kith's own logs would carry handles and titles out with
    # them. Outbound HTTP is the useful half and names nobody.
    config.breadcrumbs_logger = [ :http_logger ]

    # Errors, and nothing else. sentry-rails 7 ships Rails' structured logs by
    # default, and its ActionController subscriber sends the path of *every*
    # request — so a healthy GET of /join/<code> would post that invite to
    # Splat, on a request that did not even fail. Kith wants a record of what
    # broke, not a copy of its access log somewhere else.
    config.rails.structured_logging.enabled = false

    # Tracing is off unless asked for. Forty people do not generate a
    # performance question, and every transaction is another URL to scrub.
    config.traces_sample_rate = ENV.fetch("SENTRY_TRACES_SAMPLE_RATE", 0.0).to_f

    # Noise, all of it: a 404 from a scanner, a stale form's CSRF token.
    config.excluded_exceptions += [
      "ActionController::BadRequest",
      "ActionController::InvalidAuthenticityToken",
      "ActionController::RoutingError",
      "ActionController::UnknownFormat",
      "ActiveRecord::RecordNotFound"
    ]

    config.before_send = ->(event, _hint) { ErrorReport.scrub(event) }
    config.before_send_transaction = ->(event, _hint) { ErrorReport.scrub(event) }

    # Wired even though logs are off above: a switch and a hook that disagree
    # is how a later "let's just turn logs on" becomes a leak nobody looks for.
    config.before_send_log = ->(log) { ErrorReport.scrub_log(log) }
  end

  Sentry.set_tags(revision: Rails.application.config.x.revision)
end
