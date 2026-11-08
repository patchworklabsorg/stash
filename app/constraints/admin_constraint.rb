# frozen_string_literal: true

class AdminConstraint
  def initialize(policy_method)
    @policy_method = policy_method
  end

  def matches?(request)
    token = request.cookie_jar.signed[:session_token]
    return false unless token

    session = Session.find_by(token: token)
    return false unless session&.user

    AdminPolicy.new(session.user, :admin).public_send(@policy_method)
  rescue StandardError
    false
  end
end
