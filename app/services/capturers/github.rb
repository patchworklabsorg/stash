require "net/http"

module Capturers
  # What GitHub knows about a repository, from its REST API: the repository record, the README,
  # the releases, the last 100 commits and the contributors. All of it goes into github.json
  # (metadata), and the README also into README.md as served (metadata).
  #
  # GITHUB_TOKEN raises the rate limit from 60 to 5000 requests an hour. It is optional.
  class Github < Base
    API = "https://api.github.com".freeze

    def call
      owner, repo = Router.github_repo(url)
      raise Skip, "not a GitHub repository URL" unless owner

      record = {
        "captured_at" => Time.current.iso8601,
        "repository" => get("/repos/#{owner}/#{repo}"),
        "releases" => get("/repos/#{owner}/#{repo}/releases?per_page=100"),
        "commits" => get("/repos/#{owner}/#{repo}/commits?per_page=100"),
        "contributors" => get("/repos/#{owner}/#{repo}/contributors?per_page=100", allow_empty: true)
      }
      readme = get("/repos/#{owner}/#{repo}/readme", raw: true, allow_missing: true)
      record["readme_present"] = readme.present?
      write_json("github.json", record)
      outputs = [ output("metadata", "github.json", content_type: "application/json") ]
      if readme
        ::File.binwrite(path("README.md"), readme)
        outputs << output("metadata", "README.md", content_type: "text/markdown")
      end
      outputs
    end

    private

    def get(route, raw: false, allow_missing: false, allow_empty: false)
      uri = URI("#{API}#{route}")
      request = Net::HTTP::Get.new(uri)
      request["Accept"] = raw ? "application/vnd.github.raw+json" : "application/vnd.github+json"
      request["X-GitHub-Api-Version"] = "2022-11-28"
      request["User-Agent"] = Download::USER_AGENT
      request["Authorization"] = "Bearer #{ENV["GITHUB_TOKEN"]}" if ENV["GITHUB_TOKEN"].present?
      log("GET #{uri.path}")
      response = Download.start(uri) { |http| http.request(request) }
      case response
      when Net::HTTPSuccess then raw ? response.body : JSON.parse(response.body)
      when Net::HTTPNotFound
        return nil if allow_missing
        raise ToolFailed, "GitHub answered 404 for #{uri.path}: the repository is private or gone"
      when Net::HTTPNoContent, Net::HTTPAccepted
        return [] if allow_empty
        raise ToolFailed, "GitHub answered #{response.code} for #{uri.path}"
      else
        raise ToolFailed, "GitHub answered #{response.code} for #{uri.path}"
      end
    rescue SocketError, SystemCallError, Net::OpenTimeout, Net::ReadTimeout, OpenSSL::SSL::SSLError => e
      raise ToolFailed, "could not reach GitHub: #{e.class}"
    rescue JSON::ParserError
      raise ToolFailed, "GitHub answered with malformed JSON"
    end
  end
end
