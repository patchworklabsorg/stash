# Lets only a signed-in admin reach a mounted engine (the GoodJob dashboard). It reads the same
# encrypted session cookie as the Authentication concern.
class AdminConstraint
  def matches?(request)
    user = SessionUser.from_session(request.session[:user])
    user.present? && !user.expired? && user.admin?
  rescue StandardError
    false
  end
end
