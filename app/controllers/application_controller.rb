class ApplicationController < ActionController::Base
  include Authentication
  include Pundit::Authorization
  # Active Storage's Disk service builds its signed URLs from the current request. Without this,
  # Artifact#file.url raises in production with STASH_STORAGE_SERVICE=disk.
  include ActiveStorage::SetCurrent

  # Only allow modern browsers supporting webp images, web push, badges, import maps, CSS nesting, and CSS :has.
  allow_browser versions: :modern

  rescue_from Pundit::NotAuthorizedError, with: :render_forbidden

  private

  # Pundit reads the signed-in person from here.
  def pundit_user
    current_user
  end
end
