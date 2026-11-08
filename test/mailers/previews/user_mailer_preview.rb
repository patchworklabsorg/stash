# frozen_string_literal: true

# Preview emails at http://localhost:3000/rails/mailers/user_mailer
class UserMailerPreview < ActionMailer::Preview
  def welcome
    user = User.first || OpenStruct.new(email: 'user@example.com')
    UserMailer.welcome(user)
  end

  def password_reset
    user = User.first || OpenStruct.new(email: 'user@example.com')
    UserMailer.password_reset(user, 'sample_token_123')
  end

  def email_confirmation
    user = User.first || OpenStruct.new(email: 'user@example.com')
    UserMailer.email_confirmation(user, 'sample_token_123')
  end
end
