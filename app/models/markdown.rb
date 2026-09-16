# Post bodies are written in Markdown and rendered once, at write time.
#
# Two defences, belt and braces: CommonMarker renders with unsafe HTML
# disabled, so raw tags in the source never become tags in the output, and the
# result is then run through Rails' sanitiser against an explicit allowlist.
# Neither alone is trusted.
module Markdown
  TAGS = %w[
    p br hr
    h1 h2 h3 h4 h5 h6
    strong em del code pre blockquote
    ul ol li
    a img
    table thead tbody tr th td
  ].freeze

  ATTRIBUTES = %w[ href title alt src ].freeze

  PROTOCOLS = %w[ http https mailto ].freeze

  OPTIONS = {
    parse: { smart: true },
    render: { unsafe: false, hardbreaks: true, github_pre_lang: true },
    extension: { strikethrough: true, table: true, autolink: true, tagfilter: true }
  }.freeze

  def self.render(source)
    return "" if source.blank?

    html = Commonmarker.to_html(source.to_s, options: OPTIONS)

    Rails::HTML5::SafeListSanitizer.new.sanitize(
      html,
      tags: TAGS,
      attributes: ATTRIBUTES,
      protocols: PROTOCOLS
    ).html_safe
  end

  # First paragraph or so, for notification and feed summaries. Plain text: no
  # markup survives.
  def self.excerpt(source, length: 160)
    Rails::HTML5::FullSanitizer.new.sanitize(render(source)).to_s.squish.truncate(length)
  end
end
