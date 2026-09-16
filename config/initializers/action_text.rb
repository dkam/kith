# What a post body is allowed to be, once it has been rendered.
#
# Action Text sanitises on the way out rather than on the way in, so this list
# is the last thing standing between a stored body and the page. Rails' default
# is Loofah's full safe list, and Lexxy widens it further — video, audio,
# source, embed, and a style attribute. Kith is a reader for a few dozen
# friends; none of that has a reason to exist in a post, and an allowlist is
# only worth having if it is the shortest one that works.
#
# Two attributes are deliberately absent, and they are the point of the list:
#
#   url   the Active Storage blob URL Lexxy previews a photo from. It works for
#         anyone holding it, forever, without asking who they are. Post strips
#         it before storing; leaving it out here means a body that somehow kept
#         one still cannot hand it to a reader.
#   sgid  the blob's signed global id. Nothing on the page needs it, and a
#         reader's browser is not where it belongs.
#
# Photos reach the page through MediaController instead, which re-checks the
# post's audience on every single request. See app/views/active_storage/blobs.
ActiveSupport.on_load(:action_text_content) do
  ActionText::ContentHelper.sanitizer = Rails::HTML5::SafeListSanitizer.new

  ActionText::ContentHelper.allowed_tags = %w[
    p br hr div span
    h1 h2 h3 h4 h5 h6
    strong b em i u s del mark
    code pre blockquote
    ul ol li
    a img figure figcaption
    table thead tbody tfoot tr th td
    action-text-attachment
  ].freeze

  ActionText::ContentHelper.allowed_attributes = %w[
    class dir href target rel src alt loading title data-language value start
    content-type filename filesize width height previewable presentation caption
  ].freeze
end
