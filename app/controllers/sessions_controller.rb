# The sign-in page, the Weave OIDC flow and sign-out.
class SessionsController < ApplicationController
  allow_unauthenticated_access
  layout "focus"

  def new
    redirect_to archives_path if current_user&.reader?
  end

  # POST /auth/weave: starts the Authorization Code flow with PKCE.
  def create
    state = Weave::OidcClient.random_token
    nonce = Weave::OidcClient.random_token
    code_verifier = Weave::OidcClient.random_token
    session[:oidc] = { "state" => state, "nonce" => nonce, "code_verifier" => code_verifier }

    url = Weave::OidcClient.new.authorization_url(
      state: state, nonce: nonce, code_verifier: code_verifier, redirect_uri: auth_callback_url
    )
    redirect_to url, allow_other_host: true
  rescue Weave::ConfigurationError, Weave::UnavailableError => e
    sign_in_failed(e)
  end

  # GET /auth/callback: Weave sends the user back here with a code.
  def callback
    oidc = session.delete(:oidc)
    raise Weave::AuthError, params[:error].to_s if params[:error].present?
    raise Weave::AuthError, "no sign-in in progress" unless oidc.is_a?(Hash)
    unless ActiveSupport::SecurityUtils.secure_compare(params[:state].to_s, oidc["state"].to_s)
      raise Weave::AuthError, "state does not match"
    end

    identity = Weave::OidcClient.new.exchange_code(
      code: params[:code].to_s, code_verifier: oidc["code_verifier"], redirect_uri: auth_callback_url,
      nonce: oidc["nonce"]
    )
    start_session(sub: identity.sub, name: identity.name, email: identity.email, roles: identity.roles)
  rescue Weave::Error => e
    sign_in_failed(e)
  end

  def destroy
    reset_session
    redirect_to sign_in_path, notice: "You are signed out."
  end

  private

  def sign_in_failed(error)
    Rails.logger.warn("Weave sign-in failed: #{error.class}: #{error.message}")
    reset_session
    redirect_to sign_in_path, alert: "Sign-in with Weave failed. Try again."
  end
end
