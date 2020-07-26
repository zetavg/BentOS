class User < ApplicationRecord
  devise :database_authenticatable, :rememberable, :recoverable, :lockable,
         :registerable, :validatable, :confirmable

  protected

  def password_required?
    false
  end
end
