class RegistrationsController < ApplicationController
  skip_before_action :authenticate, only: %i[new create]

  def new
    redirect_to root_path if signed_in?
    @user = User.new
  end

  def create
    @user = User.new(user_params)
    if @user.save
      start_session(@user)
      redirect_to root_path, notice: 'Account created successfully.'
    else
      render :new, status: :unprocessable_entity
    end
  end

  private

  def user_params
    params.require(:user).permit(:email, :password, :password_confirmation)
  end
end
