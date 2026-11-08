class ApplicationController < ActionController::Base
include SetPaperTrailWhodunnit
include Trackable
helper FeatureHelper
include Pundit::Authorization
after_action :verify_authorized, except: :index, unless: :skip_pundit?
after_action :verify_policy_scoped, only: :index, unless: :skip_pundit?

rescue_from Pundit::NotAuthorizedError, with: :user_not_authorized

private

def user_not_authorized
  flash[:alert] = 'You are not authorized to perform this action.'
  redirect_back(fallback_location: root_path)
end

def skip_pundit?
  devise_controller? rescue false || self.class.to_s.start_with?('Sessions', 'Registrations')
end
include Authentication
# Invisible captcha is available in forms via: invisible_captcha
# Add to specific controllers with: invisible_captcha only: [:create], on_spam: :spam_detected
#
# private
# def spam_detected
#   redirect_to root_path, alert: 'Spam detected.'
# end
end
