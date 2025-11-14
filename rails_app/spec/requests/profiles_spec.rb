# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Profiles", type: :request do
  describe "GET /profile" do
    it "redirects guests to the sign in page" do
      get profile_path, headers: default_headers

      expect(response).to redirect_to(new_user_session_path)
    end

    it "returns success for authenticated users" do
      user = create(:user)
      sign_in user

      get profile_path, headers: default_headers

      expect(response).to have_http_status(:ok)
    end
  end

  describe "GET /profile/edit" do
    it "redirects guests to the sign in page" do
      get edit_profile_path, headers: default_headers

      expect(response).to redirect_to(new_user_session_path)
    end

    it "returns success for authenticated users" do
      user = create(:user)
      sign_in user

      get edit_profile_path, headers: default_headers

      expect(response).to have_http_status(:ok)
    end
  end

  describe "PATCH /profile" do
    let(:user) { create(:user) }
    let(:profile) { user.profile }

    it "redirects guests to the sign in page" do
      patch profile_path, params: { profile: { full_name: "New Name" } }, headers: default_headers

      expect(response).to redirect_to(new_user_session_path)
    end

    it "updates the profile with valid parameters" do
      sign_in user

      patch profile_path, params: {
        profile: {
          full_name: "New Name",
          github_url: "https://github.com/example"
        }
      }, headers: default_headers

      expect(response).to redirect_to(profile_path)
      expect(flash[:notice]).to eq("Profil mis à jour.")
      expect(profile.reload.full_name).to eq("New Name")
      expect(profile.github_url).to eq("https://github.com/example")
    end

    it "renders the edit template with invalid data" do
      sign_in user

      patch profile_path, params: { profile: { github_url: "invalid" } }, headers: default_headers

      expect(response).to have_http_status(:unprocessable_entity)
      expect(profile.reload.github_url).to be_blank
    end
  end
end
