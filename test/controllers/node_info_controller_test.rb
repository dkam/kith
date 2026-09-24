require "test_helper"

class NodeInfoControllerTest < ActionDispatch::IntegrationTest
  test "the pointer names the document" do
    get nodeinfo_index_url

    assert_response :success
    assert_equal "application/json", response.media_type

    link = JSON.parse(response.body)["links"].sole
    assert_equal "http://nodeinfo.diaspora.software/ns/schema/2.1", link["rel"]
    assert_equal nodeinfo_url, link["href"]
  end

  test "an app can tell this is a Kith before it shows anybody a password box" do
    assert_equal "kith", document["software"]["name"]
    assert_equal Kith::VERSION, document["software"]["version"]
    assert_equal "2.1", document["version"]
  end

  test "nobody can sign up, and the document says so" do
    assert_equal false, document["openRegistrations"]
  end

  # Federation is a seam, not a feature. Claiming a protocol here is promising
  # to answer an inbox that does not exist yet.
  test "no protocol is claimed that Kith cannot answer" do
    assert_empty document["protocols"]
    assert_empty document["services"]["inbound"]
    assert_empty document["services"]["outbound"]
  end

  # The one rule this document could quietly break. Counts are disclosures, and
  # this one would be published to anybody who asks, forever.
  test "how many people are in here is nobody's business" do
    assert_not document.key?("usage"), "NodeInfo is publishing a member count"
    assert_no_match(/#{Member.count}/, response.body)
  end

  test "an app is told where its rules are and how old it may be" do
    metadata = document["metadata"]

    assert_equal Kith::MINIMUM_NATIVE_VERSION, metadata["minimumNativeVersion"]
    assert_equal hotwire_configuration_path("ios_v1"), metadata["pathConfiguration"]["ios"]
    assert_equal hotwire_configuration_path("android_v1"), metadata["pathConfiguration"]["android"]
  end

  test "both documents answer a stranger, and a cache may keep them" do
    [ nodeinfo_index_url, nodeinfo_url ].each do |url|
      get url

      assert_response :success
      assert_match "public", response.headers["Cache-Control"]
    end
  end

  private
    def document
      get nodeinfo_url
      JSON.parse(response.body)
    end
end
