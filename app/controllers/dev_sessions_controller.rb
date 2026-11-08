# The dev-only sign-in (STASH_AUTH_MODE=dev). It signs you in as a fake user with the roles you pick.
# The routes exist only in dev mode, the app refuses to boot with dev mode in production,
# and this controller checks the mode again on each request.
class DevSessionsController < ApplicationController
  allow_unauthenticated_access
  before_action :require_dev_mode

  PRESETS = [
    { sub: "PWLDEVADMIN01", name: "Ada Admin", roles: %w[admin] },
    { sub: "PWLDEVARCHIV1", name: "Archie Archivist", roles: %w[archivist] },
    { sub: "PWLDEVVIEWER1", name: "Vic Viewer", roles: %w[viewer] },
    { sub: "PWLDEVNOROLES", name: "Nora Norole", roles: [] }
  ].freeze

  def new
  end

  def create
    sub = params.require(:sub).to_s.strip
    raise ActionController::BadRequest, "sub is required" if sub.blank?

    start_session(sub: sub, name: params[:name].to_s.strip, email: "#{sub.downcase}@dev.invalid",
      roles: Array(params[:roles]))
  end

  private

  def require_dev_mode
    raise ActionController::RoutingError, "Not Found" unless Stash::AuthMode.dev?
  end
end
