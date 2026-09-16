require "test_helper"

class MarkdownTest < ActiveSupport::TestCase
  test "renders ordinary Markdown" do
    html = Markdown.render("A **bold** claim and a [link](https://example.com).")

    assert_includes html, "<strong>bold</strong>"
    assert_includes html, %(href="https://example.com")
  end

  test "renders lists, quotes and code" do
    html = Markdown.render("- one\n- two\n\n> quoted\n\n`code`")

    assert_includes html, "<ul>"
    assert_includes html, "<blockquote>"
    assert_includes html, "<code>code</code>"
  end

  test "raw HTML in the source never becomes HTML in the output" do
    html = Markdown.render("<script>alert('x')</script>")

    refute_includes html, "<script"
    refute_includes html, "alert("
  end

  test "inline event handlers are stripped" do
    html = Markdown.render(%(<img src="x" onerror="alert(1)">))

    refute_includes html, "onerror"
  end

  test "javascript: links are stripped" do
    html = Markdown.render("[click](javascript:alert(1))")

    refute_includes html, "javascript:"
  end

  test "iframes and objects do not survive" do
    html = Markdown.render(%(<iframe src="https://evil.example"></iframe>))

    refute_includes html, "<iframe"
  end

  test "the output is marked html_safe so views do not double-escape it" do
    assert Markdown.render("hello").html_safe?
  end

  test "blank input renders to nothing" do
    assert_equal "", Markdown.render(nil)
    assert_equal "", Markdown.render("  ")
  end

  test "excerpt returns plain text with the markup removed" do
    excerpt = Markdown.excerpt("# Heading\n\nA **bold** claim.")

    assert_equal "Heading A bold claim.", excerpt
    refute_includes excerpt, "<"
  end

  test "excerpt truncates" do
    assert_equal 20, Markdown.excerpt("word " * 50, length: 20).length
  end
end
