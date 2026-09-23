require "active_support/core_ext/integer/time"

Rails.application.configure do
  # Settings specified here will take precedence over those in config/application.rb.

  # Where this Kith lives. Every link in an email is built from it and every
  # Host header is checked against it, so there is no sensible default to fall
  # back on: a guess produces a password reset that arrives, looks right and
  # leads nowhere — which is precisely what Rails' generated "example.com" did.
  # Better to refuse to start and say so.
  #
  # One boot is exempt. The image build runs assets:precompile in this
  # environment, long before anybody has chosen a hostname and with nothing
  # being served; Rails marks that boot with SECRET_KEY_BASE_DUMMY.
  host = ENV["KITH_HOST"].presence
  host ||= "kith.invalid" if ENV["SECRET_KEY_BASE_DUMMY"]
  raise "KITH_HOST is not set: Kith needs to know its own address. See .env.example." if host.nil?

  # Code is not reloaded between requests.
  config.enable_reloading = false

  # Eager load code on boot for better performance and memory savings (ignored by Rake tasks).
  config.eager_load = true

  # Full error reports are disabled.
  config.consider_all_requests_local = false

  # Turn on fragment caching in view templates.
  config.action_controller.perform_caching = true

  # Cache assets for far-future expiry since they are all digest stamped.
  config.public_file_server.headers = { "cache-control" => "public, max-age=#{1.year.to_i}" }

  # Enable serving of images, stylesheets, and JavaScripts from an asset server.
  # config.asset_host = "http://assets.example.com"

  # Store uploaded files on the local file system (see config/storage.yml for options).
  config.active_storage.service = :local

  # TLS is terminated by the proxy in front, which then speaks plain http to
  # this container. Without this, Rails believes every request arrived
  # unencrypted: cookies are set without `secure`, and a form POST can 422 on
  # the CSRF origin check — an http Origin held against an https base URL.
  config.assume_ssl = true

  # Strict-Transport-Security, secure cookies, and http redirected to https.
  config.force_ssl = true

  # Except for the health check, which is the container asking itself over
  # http, by a name no certificate covers.
  config.ssl_options = { redirect: { exclude: ->(request) { request.path == "/up" } } }

  # Log to STDOUT with the current request id as a default log tag.
  config.log_tags = [ :request_id ]
  config.logger   = ActiveSupport::TaggedLogging.logger(STDOUT)

  # Change to "debug" to log everything (including potentially personally-identifiable information!).
  config.log_level = ENV.fetch("RAILS_LOG_LEVEL", "info")

  # Prevent health checks from clogging up the logs.
  config.silence_healthcheck_path = "/up"

  # Don't log any deprecations.
  config.active_support.report_deprecations = false

  # Replace the default in-process memory cache store with a durable alternative.
  config.cache_store = :solid_cache_store

  # Replace the default in-process and non-durable queuing backend for Active Job.
  config.active_job.queue_adapter = :solid_queue
  config.solid_queue.connects_to = { database: { writing: :queue } }

  # An email has no page to be relative to, so every link in one is absolute —
  # and https, because that is the only way in.
  config.action_mailer.default_url_options = { host: host, protocol: "https" }

  # The relay. Nothing here is a credential in the repository: an SMTP password
  # is as good as the mailbox it belongs to, so it arrives from the
  # environment like every other secret Kith holds.
  #
  # Every one of these is read for its *presence*: compose hands the container
  # `SMTP_ADDRESS=` rather than nothing at all when the variable is unset in
  # .env, and ENV.fetch takes an empty string for an answer — which is a relay
  # at "" on port 0.
  #
  # `domain` is what Kith calls itself at HELO, and a relay that does not
  # recognise it will refuse the message — which is why it is the same host as
  # the links, rather than the container's id.
  config.action_mailer.smtp_settings = {
    address: ENV["SMTP_ADDRESS"].presence || "localhost",
    port: (ENV["SMTP_PORT"].presence || 587).to_i,
    domain: host,
    user_name: ENV["SMTP_USER_NAME"].presence,
    password: ENV["SMTP_PASSWORD"].presence,
    authentication: (:plain if ENV["SMTP_USER_NAME"].present?),
    enable_starttls_auto: true
  }.compact

  # Delivery errors are left to raise, which is Rails' default and the right
  # way round here: the reset is sent with deliver_later, so a relay that
  # refuses it fails in the worker, retries, and is visible — rather than a
  # member waiting on an email that was never going to arrive.

  # Enable locale fallbacks for I18n (makes lookups for any locale fall back to
  # the I18n.default_locale when a translation cannot be found).
  config.i18n.fallbacks = true

  # Do not dump schema after migrations.
  config.active_record.dump_schema_after_migration = false

  # Only use :id for inspections in production.
  config.active_record.attributes_for_inspect = [ :id ]

  # DNS rebinding and Host header attacks: Kith answers to its own name and to
  # nothing else. A request that arrives by IP address, or under somebody
  # else's hostname, is not one of ours.
  config.hosts = [ host ]

  # Except the health check again, which the container makes against localhost.
  config.host_authorization = { exclude: ->(request) { request.path == "/up" } }
end
