# Sign-in state for every controller.
#
# The session holds a SessionUser: the Weave sub, name, roles and the sign-in time.
# A session older than config.x.session_lifetime (8 hours) is cleared, and the user must sign in again.
# A user with no Stash role never gets a session (see #start_session).
module Authentication
  extend ActiveSupport::Concern

  class Forbidden < StandardError; end

  included do
    before_action :require_reader
    helper_method :current_user, :signed_in?
    rescue_from Forbidden, with: :render_forbidden
  end

  class_methods do
    def allow_unauthenticated_access(**options)
      skip_before_action :require_reader, **options
    end
  end

  private

  def current_user
    return @current_user if defined?(@current_user)

    user = SessionUser.from_session(session[:user])
    @current_user = user && !user.expired? ? user : nil
  end

  def signed_in?
    current_user.present?
  end

  def require_reader
    if current_user.nil?
      expired = session[:user].present?
      reset_session
      redirect_to sign_in_path, alert: expired ? "Your session expired. Sign in again." : nil
    elsif !current_user.reader?
      raise Forbidden
    end
  end

  # Starts a session for a user with at least one Stash role. Without a role, the user gets
  # a 403 page and no session. reset_session first, so an old session id is never reused.
  def start_session(sub:, name:, email:, roles:)
    reset_session
    user = SessionUser.new(sub: sub, name: name, email: email, roles: Weave::Roles.from_claim(roles),
      signed_in_at: Time.current)
    raise Forbidden unless user.reader?

    session[:user] = user.to_session
    @current_user = user
    redirect_to archives_path
  end

  def render_forbidden
    render "errors/forbidden", status: :forbidden
  end
end
