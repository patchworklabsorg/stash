# frozen_string_literal: true

class UserMailer < ApplicationMailer
  def welcome(user)
    @user = user
    @login_url = sign_in_url

    mail(
      to: @user.email,
      subject: "Welcome to #{Rails.application.class.module_parent_name}"
    )
  end

  def password_reset(user, token)
    @user = user
    @token = token
    @reset_url = edit_password_reset_url(token: @token)

    mail(
      to: @user.email,
      subject: 'Reset your password'
    )
  end

  def email_confirmation(user, token)
    @user = user
    @token = token
    @confirm_url = confirm_email_url(token: @token)

    mail(
      to: @user.email,
      subject: 'Confirm your email address'
    )
  end
end
