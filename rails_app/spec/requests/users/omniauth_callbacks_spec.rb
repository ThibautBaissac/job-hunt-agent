# frozen_string_literal: true

require "rails_helper"
require "uri"

RSpec.describe "Google OAuth callbacks", type: :request do
  let(:callback_path) { user_google_oauth2_omniauth_callback_path }

  around do |example|
    OmniAuth.config.test_mode = true

    example.run
  ensure
    OmniAuth.config.test_mode = false
    OmniAuth.config.mock_auth[:google_oauth2] = nil
  end

  it "requires authentication" do
    get callback_path, headers: default_headers

    expect(response).to redirect_to(new_user_session_path)
    expect(flash[:alert]).to eq("Connectez-vous pour lier Gmail.")
  end

  context "when signed in" do
    let(:user) { create(:user) }

    before do
      sign_in user
    end

    it "handles missing auth payload" do
      allow_any_instance_of(Users::OmniauthCallbacksController).to receive(:request).and_wrap_original do |original|
        request = original.call
        env = request.env.clone
        env["omniauth.auth"] = nil
        allow(request).to receive(:env).and_return(env)
        request
      end

      get callback_path, headers: default_headers

      expect(response).to redirect_to(profile_path)
      expect(flash[:alert]).to eq("Impossible de récupérer les informations Google.")
    end

    it "rejects mismatched email" do
      auth_hash = OmniAuth::AuthHash.new(
        provider: "google_oauth2",
        uid: "123",
        info: { email: "other@example.com" },
        credentials: { token: "token", refresh_token: "refresh", expires_at: 1.hour.from_now.to_i }
      )
      OmniAuth.config.mock_auth[:google_oauth2] = auth_hash

      get callback_path, headers: default_headers

      expect(response).to redirect_to(profile_path)
      expect(flash[:alert]).to eq("L'email Google ne correspond pas à votre compte.")
    end

    it "connects the account when data is valid" do
      auth_hash = OmniAuth::AuthHash.new(
        provider: "google_oauth2",
        uid: "123",
        info: { email: user.email },
        credentials: { token: "token", refresh_token: "refresh", expires_at: 1.hour.from_now.to_i }
      )
      OmniAuth.config.mock_auth[:google_oauth2] = auth_hash
      allow(User).to receive(:connect_google_account!).and_call_original

      get callback_path, headers: default_headers

      expect(response).to redirect_to(profile_path)
      expect(flash[:notice]).to eq("Gmail connecté avec succès.")
      expect(User).to have_received(:connect_google_account!).with(user: user, auth: auth_hash)
    end

    it "logs and alerts when the link fails" do
      auth_hash = OmniAuth::AuthHash.new(
        provider: "google_oauth2",
        uid: "123",
        info: { email: user.email },
        credentials: { token: "token", refresh_token: "refresh", expires_at: 1.hour.from_now.to_i }
      )
      OmniAuth.config.mock_auth[:google_oauth2] = auth_hash
      allow(User).to receive(:connect_google_account!).and_raise(StandardError, "boom")
      allow(Rails.logger).to receive(:error)

      get callback_path, headers: default_headers

      expect(response).to redirect_to(profile_path)
      expect(flash[:alert]).to eq("Erreur lors de la connexion Gmail. Merci de réessayer.")
      expect(Rails.logger).to have_received(:error).with(/boom/)
    end
  end

  describe "failure callback" do
    it "redirects with an alert" do
      env = Rack::MockRequest.env_for("/users/auth/failure")
      env["devise.mapping"] = Devise.mappings[:user]

      status, headers, _body = Users::OmniauthCallbacksController.action(:failure).call(env)

      expect(status).to eq(302)
      expect(URI.parse(headers["Location"]).path).to eq("/profile")
    end
  end
end
