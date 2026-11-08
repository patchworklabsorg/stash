module Api
  module V1
    # The base for the patch API. JSON only: no session, no cookies, no CSRF token.
    #
    # Each request needs `Authorization: Bearer <token>`, a Weave client_credentials token with
    # scope `stash`. Weave::Introspection checks it, and the token's client_id is stored on the archive.
    #
    #   no token, or Weave says it is not active     401 invalid_token
    #   active, but without the stash scope          403 insufficient_scope
    #   Weave does not answer                        503 weave_unavailable (the patch app retries)
    #
    # Never log the token. The Authorization header is filtered (filter_parameter_logging.rb)
    # and Logstop scrubs bearer tokens.
    class BaseController < ActionController::API
      SCOPE = "stash".freeze

      before_action :authenticate_client!

      rescue_from ActiveRecord::RecordNotFound do
        render json: { error: "not_found" }, status: :not_found
      end

      private

      attr_reader :current_client_id

      def authenticate_client!
        token = bearer_token
        return render_unauthorized if token.nil?

        result = Weave::Introspection.new.call(token)
        return render_unauthorized unless result.active?
        return render_forbidden("insufficient_scope") unless result.scope?(SCOPE)

        @current_client_id = result.client_id.presence || "unknown"
      rescue Weave::UnavailableError, Weave::ConfigurationError => e
        Rails.logger.warn("API: could not check a token with Weave: #{e.class}: #{e.message}")
        render json: { error: "weave_unavailable" }, status: :service_unavailable
      end

      def bearer_token
        scheme, token = request.authorization.to_s.split(" ", 2)
        token = token.to_s.strip
        scheme&.casecmp?("Bearer") && token.present? ? token : nil
      end

      def render_unauthorized
        response.headers["WWW-Authenticate"] = %(Bearer realm="stash", error="invalid_token")
        render json: { error: "invalid_token" }, status: :unauthorized
      end

      def render_forbidden(error)
        response.headers["WWW-Authenticate"] = %(Bearer realm="stash", error="insufficient_scope", scope="#{SCOPE}")
        render json: { error: error }, status: :forbidden
      end
    end
  end
end
