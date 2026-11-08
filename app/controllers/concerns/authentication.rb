module Authentication
  extend ActiveSupport::Concern

  included do
    before_action :authenticate
    helper_method :signed_in?, :current_user
  end

  private

  def authenticate
    if (session_record = find_session_by_cookie)
      Current.session = session_record
    end
  end

  def require_authentication
    redirect_to sign_in_path, alert: 'Please sign in to continue.' unless signed_in?
  end

  def require_admin
    require_authentication
    return if current_user&.admin_or_above?

    redirect_to root_path, alert: 'You are not authorized to access this page.'
  end

  def require_super_admin
    require_authentication
    return if current_user&.super_admin?

    redirect_to root_path, alert: 'You are not authorized to access this page.'
  end

  def signed_in?
    Current.session.present?
  end

  def current_user
    Current.user
  end

  def find_session_by_cookie
    Session.find_by(token: cookies.signed[:session_token])
  end

  def start_session(user)
    session_record = user.sessions.create!(
      ip_address: request.remote_ip,
      user_agent: request.user_agent
    )
    cookies.signed.permanent[:session_token] = {
      value: session_record.token,
      httponly: true,
      same_site: :lax
    }
    Current.session = session_record
  end

  def end_session
    Current.session&.destroy
    cookies.delete(:session_token)
  end
end
