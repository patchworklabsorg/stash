class Session < ApplicationRecord
  belongs_to :user

  before_create :generate_token

  validates :token, presence: true, uniqueness: true

  private

  def generate_token
    self.token = SecureRandom.urlsafe_base64(32)
  end
end
