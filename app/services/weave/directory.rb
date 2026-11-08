module Weave
  # Reads one person from Weave's directory API, live, before a person's action that moves money.
  #
  #   GET {WEAVE_ISSUER}/api/v1/directory/users/:sub
  #
  # Stash calls it with its own client_credentials token, scope `directory` (Weave::ClientCredentials).
  # Weave answers with the person's record as Stash's app sees it: `roles` holds only the role keys
  # of the Stash app, and `active` is false when the person cannot sign in. A person that Stash's app
  # may not serve is a 404, the same as an unknown sub.
  #
  # Answers are never cached: each check asks Weave again. When Weave does not answer, answers with
  # an error, or refuses Stash's token, this raises UnavailableError, so the caller fails closed.
  # On a 401, Stash gets a new token once and asks again.
  class Directory
    include Http

    SCOPE = "directory".freeze
    PATH = "/api/v1/directory/users/".freeze

    # One person as Weave's directory shows it to Stash. roles are Stash role keys (Weave::Roles).
    User = Data.define(:sub, :name, :email, :roles, :active) do
      def active?
        active
      end

      def archivist?
        active? && roles.intersect?(%w[archivist admin])
      end
    end

    def initialize(tokens: ClientCredentials.new)
      @tokens = tokens
    end

    # Returns a User, or nil when Weave does not know the sub (or Stash may not see it).
    def user(sub)
      raise ArgumentError, "sub is blank" if sub.blank?

      uri = URI("#{Config.issuer}#{PATH}#{ERB::Util.url_encode(sub)}")
      response = get(uri)
      if response.code == "401"
        @tokens.forget(SCOPE)
        response = get(uri)
      end

      case response.code
      when "200" then parse_user(parse_json(response.body), sub)
      when "404" then nil
      when "403"
        raise UnavailableError, "Weave's directory refused Stash's token (403). Allow the directory scope on the Stash app in Weave."
      else
        raise UnavailableError, "Weave's directory answered #{response.code}"
      end
    end

    private

    def get(uri)
      request = Net::HTTP::Get.new(uri.request_uri)
      request["Authorization"] = "Bearer #{@tokens.token(SCOPE)}"
      request["Accept"] = "application/json"
      http_for(uri) { |http| http.request(request) }
    end

    # A record for another sub, or with no sub, is malformed. Only the JSON value true is active,
    # and a roles value that is not a list counts as no roles, so a bad answer fails closed.
    def parse_user(body, sub)
      raise UnavailableError, "Weave's directory answered a record for another user" unless body["sub"] == sub

      User.new(
        sub: sub,
        name: body["name"].is_a?(String) ? body["name"] : "",
        email: body["email"].is_a?(String) ? body["email"] : "",
        roles: Roles.from_claim(body["roles"]),
        active: body["active"] == true
      )
    end
  end
end
