# frozen_string_literal: true

module Admin
  class ApplicationController < ::ApplicationController
    before_action :require_admin

    def index
      @current_user = current_user
    end

    private

    def require_admin
      unless current_user&.admin_or_above?
        redirect_to root_path, alert: 'You are not authorized to access this area.'
      end
    end
  end
end
