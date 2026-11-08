class SessionsController < ApplicationController
  skip_before_action :authenticate, only: %i[new create]

  def new
    redirect_to root_path if signed_in?
  end

  def create
    if (user = User.find_by(email: params[:email])&.authenticate(params[:password]))
      start_session(user)
      redirect_to root_path, notice: 'Signed in successfully.'
    else
      flash.now[:alert] = 'Invalid email or password.'
      render :new, status: :unprocessable_entity
    end
  end

  def destroy
    end_session
    redirect_to root_path, notice: 'Signed out successfully.'
  end
end
