require "test_helper"

class UrlNormalizerTest < ActiveSupport::TestCase
  test "lowercases scheme and host, drops the fragment and a trailing slash" do
    assert_equal "https://example.org/Path", UrlNormalizer.call("HTTPS://Example.ORG/Path/#top")
  end

  test "keeps the root slash and drops a default port" do
    assert_equal "https://example.org/", UrlNormalizer.call("https://example.org:443")
    assert_equal "http://example.org:8080/", UrlNormalizer.call("http://example.org:8080/")
  end

  test "drops tracking parameters and sorts the rest" do
    assert_equal "https://example.org/?a=1&b=2", UrlNormalizer.call("https://example.org/?b=2&utm_source=x&a=1&fbclid=y")
    assert_equal "https://youtu.be/abc", UrlNormalizer.call("https://youtu.be/abc?si=tracking")
  end

  test "leaves a URL it cannot parse alone" do
    assert_equal "not a url", UrlNormalizer.call(" not a url ")
  end

  test "host" do
    assert_equal "example.org", UrlNormalizer.host("HTTPS://Example.org/x")
    assert_nil UrlNormalizer.host("nope")
  end
end
