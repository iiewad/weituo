class User < ApplicationRecord
  has_secure_password
  has_many :sessions, dependent: :destroy
  has_many :user_campuses
  has_many :campuses, through: :user_campuses
  # normalizes :email_address, with: ->(e) { e.strip.downcase }
end
