# One canonical form of a URL, so two requests for the same page find each other.
#
# Lowercases the scheme and host, drops a default port, drops the fragment, drops tracking
# parameters (utm_*, fbclid, gclid), sorts the remaining query parameters, and drops a trailing
# slash on a path that is not "/". It never changes the path's case: paths are case sensitive.
module UrlNormalizer
  TRACKING = /\A(utm_|fbclid\z|gclid\z|mc_cid\z|mc_eid\z|igshid\z|si\z)/

  def self.call(url)
    uri = URI.parse(url.to_s.strip)
    return url.to_s.strip unless uri.is_a?(URI::HTTP) && uri.host

    uri.scheme = uri.scheme.downcase
    uri.host = uri.host.downcase
    uri.port = nil if uri.port == uri.default_port
    uri.fragment = nil
    uri.query = normalize_query(uri.query)
    uri.path = uri.path.chomp("/") if uri.path.length > 1
    uri.path = "/" if uri.path.empty?
    uri.to_s
  rescue URI::InvalidURIError
    url.to_s.strip
  end

  def self.host(url)
    uri = URI.parse(url.to_s.strip)
    uri.host&.downcase
  rescue URI::InvalidURIError
    nil
  end

  def self.normalize_query(query)
    return nil if query.blank?

    pairs = URI.decode_www_form(query).reject { |key, _| key.match?(TRACKING) }.sort
    pairs.empty? ? nil : URI.encode_www_form(pairs)
  rescue ArgumentError
    query
  end
  private_class_method :normalize_query
end
