class User < ApplicationRecord
  devise :database_authenticatable, :registerable,
         :recoverable, :rememberable, :validatable,
         :confirmable, :omniauthable, omniauth_providers: [ :google_oauth2 ]

  encrypts :google_access_token
  encrypts :google_refresh_token

  has_one :profile, dependent: :destroy

  after_create :ensure_profile!

  def gmail_connected?
    gmail_connected && google_access_token.present?
  end

  def google_token_expired?
    return false if google_token_expires_at.blank?

    google_token_expires_at < Time.current
  end

  def gmail_needs_reconnect?
    gmail_connected? && google_token_expired?
  end

  def disconnect_gmail!
    update!(
      gmail_connected: false,
      google_uid: nil,
      google_access_token: nil,
      google_refresh_token: nil,
      google_token_expires_at: nil
    )
  end

  def self.connect_google_account!(user:, auth:)
    credentials = auth.credentials

    user.update!(
      google_uid: auth.uid,
      gmail_connected: true,
      google_access_token: credentials.token,
      google_refresh_token: credentials.refresh_token.presence || user.google_refresh_token,
      google_token_expires_at: credentials.expires_at.present? ? Time.at(credentials.expires_at) : nil
    )

    user
  end

  private

  def ensure_profile!
    create_profile! unless profile
  end
end
