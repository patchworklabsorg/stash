class User < ApplicationRecord
  has_subscriptions
  include Featureable
  include EncodedIds::HashidIdentifiable
  set_encoded_id_prefix :usr

  has_secure_password

  enum :role, { user: 0, admin: 1, super_admin: 2, owner: 3 }, default: :user

  normalizes :email, with: ->(email) { email.strip.downcase }

  validates :email, presence: true,
                    uniqueness: { case_sensitive: false },
                    format: { with: URI::MailTo::EMAIL_REGEXP }
  validates :password, length: { minimum: 8 }, if: -> { password.present? }
  validates :role, presence: true

  # Helper method to check if user has any admin access
  def admin_or_above?
    admin? || super_admin? || owner?
  end

  # Helper method to check if user has super admin or owner access
  def super_admin_or_above?
    super_admin? || owner?
  end
end
