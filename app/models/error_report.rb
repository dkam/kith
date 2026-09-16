# What may leave the instance when something breaks.
#
# Error reporting is optional — nothing is sent unless SENTRY_DSN is set — but
# the moment it is on, a crash report is an export, and Kith is a private
# network. Sentry sends the URL of whatever failed whether or not anybody
# thought about what is in it, and four of Kith's URLs hold something that is
# nobody else's business:
#
#   /join/:code                  a live invite — a credential, still spendable
#   /passwords/:token/edit       a password reset — a credential, still usable
#   /media/:signed_id/:variant   the permission to read one photograph
#   /@:handle                    a person's name
#
# The same strings arrive a second way, which is the part that is easy to miss:
# `Referer` is in neither of sentry-ruby's PII denylists, so following a link
# off /join/<code> carries that code out in the header of whatever breaks next.
# Both doors are scrubbed here, by the same rules.
#
# This is the media rule in another costume — an opaque id is only opaque until
# it is written down somewhere else — and it follows the same principle as
# Visibility: one place decides, and there is no second path.
class ErrorReport
  FILTERED = "[filtered]"
  MASK = ActiveSupport::ParameterFilter::FILTERED

  # Ordered, first match wins: /media/pending/... has to be read before the
  # general /media/ rule or the filename would survive it.
  #
  # What is *kept* is deliberate too. The variant (thumb/feed/full) is not a
  # secret and says which size broke. /passwords/new is the form, not a token,
  # and blanking it would throw away which page failed for nothing.
  SCRUBBED_PATHS = [
    [ %r{\A/join/[^/]+}, "/join/#{FILTERED}" ],
    [ %r{\A/passwords/(?!new\z)[^/]+}, "/passwords/#{FILTERED}" ],
    [ %r{\A/media/pending/.+}, "/media/pending/#{FILTERED}" ],
    [ %r{\A/media/[^/]+(?=/)}, "/media/#{FILTERED}" ],
    [ %r{\A/@[^/]+}, "/@#{FILTERED}" ],
    [ %r{\A/actors/[^/]+/follow}, "/actors/#{FILTERED}/follow" ]
  ].freeze

  # Headers whose value is a whole URL, and so carries everything above.
  URL_HEADERS = %w[ Referer Referrer ].freeze

  # Deliberately tolerant: anything that is not a URL is not worth guessing at.
  URL = %r{\A(?<origin>\w+://[^/?#]*)?(?<path>[^?#]*)(?:\?(?<query>[^#]*))?(?:\#.*)?\z}

  class << self
    # The only thing about a member worth sending: which one, as an integer.
    # Not their handle, not their display name, not their email address — those
    # answer "is this one person or everybody?" no better, and name somebody to
    # a third party on the way.
    def identity(member)
      { id: member.id } if member
    end

    # Sentry's before_send. Returns the event so it is sent, having taken out
    # of it what should not go. Never raises: an exception in here would be
    # thrown away inside the reporter and take every later report with it.
    def scrub(event)
      request = event.request
      return event if request.nil?

      request.url = scrub_url(request.url) if request.url.present?
      request.query_string = scrub_query(request.query_string)
      scrub_headers(request.headers)

      event
    rescue StandardError
      # Something about this event is not the shape we expected. A report we
      # cannot vouch for is one we do not send.
      nil
    end

    # Sentry's before_send_log. A log event is not an error event and never
    # passes through before_send, so it needs its own door — and sentry-rails'
    # ActionController subscriber attaches `path` to *every* request, failing
    # or not.
    def scrub_log(log)
      attributes = log.attributes
      attributes[:path] = scrub_url(attributes[:path]) if attributes&.dig(:path).present?

      log
    rescue StandardError
      nil
    end

    def scrub_url(url)
      match = URL.match(url.to_s)
      return FILTERED if match.nil?

      scrubbed = "#{match[:origin]}#{scrub_path(match[:path])}"
      query = scrub_query(match[:query])

      query.present? ? "#{scrubbed}?#{query}" : scrubbed
    end

    # sentry-ruby 7 hands query params over as a Hash, and with PII off leaves
    # them out entirely — so this is mostly belt to the braces. It still has to
    # cope with both shapes rather than raise inside before_send.
    def scrub_query(query)
      case query
      when nil then nil
      when Hash then parameter_filter.filter(query)
      else query.empty? ? query : query.split("&").map { |pair| scrub_pair(pair) }.join("&")
      end
    end

    private
      def scrub_path(path)
        pattern, replacement = SCRUBBED_PATHS.find { |pattern, _| pattern.match?(path) }
        pattern ? path.sub(pattern, replacement) : path
      end

      def scrub_pair(pair)
        key, _, value = pair.partition("=")
        name = CGI.unescape(key)

        parameter_filter.filter(name => value)[name] == MASK ? "#{key}=#{MASK}" : pair
      end

      def scrub_headers(headers)
        return if headers.blank?

        URL_HEADERS.each do |name|
          headers[name] = scrub_url(headers[name]) if headers[name].present?
        end
      end

      # The same rule the logs use, so there is one answer to "is this
      # sensitive?" rather than two that can drift.
      def parameter_filter
        @parameter_filter ||= ActiveSupport::ParameterFilter.new(Rails.application.config.filter_parameters)
      end
  end
end
