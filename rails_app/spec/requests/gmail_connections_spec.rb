# frozen_string_literal: true

require "rails_helper"

RSpec.describe "GmailConnections", type: :request do
  describe "DELETE /gmail_connection" do
    it "requires authentication" do
      delete gmail_connection_path

      expect(response).to redirect_to(new_user_session_path)
    end

    it "disconnects the account and redirects" do
      user = create(
        :user,
        gmail_connected: true,
        google_access_token: "token",
        google_refresh_token: "refresh",
        google_token_expires_at: 1.hour.from_now,
        google_uid: "uid"
      )
      sign_in user

      delete gmail_connection_path, headers: default_headers

      expect(response).to redirect_to(profile_path)
      expect(flash[:notice]).to eq("Gmail déconnecté.")

      user.reload
      expect(user.gmail_connected?).to be(false)
      expect(user.google_access_token).to be_nil
      expect(user.google_refresh_token).to be_nil
    end
  end
end
