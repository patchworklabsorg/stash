# "/" sends you to sign-in, or to the archive list when you are signed in.
class HomeController < ApplicationController
  allow_unauthenticated_access

  def show
    redirect_to(current_user&.reader? ? archives_path : sign_in_path)
  end
end
