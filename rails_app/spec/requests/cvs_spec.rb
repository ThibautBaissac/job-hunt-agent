require "rails_helper"
require "warden/test/helpers"

RSpec.describe "Cvs", type: :request do
  include Warden::Test::Helpers

  let(:user) { create(:user) }

  before do
    login_as(user, scope: :user)
  end

  after do
    Warden.test_reset!
  end

  describe "GET /cvs" do
    it "renders the index" do
      get cvs_path

      expect(response).to have_http_status(:ok)
    end
  end

  describe "POST /cvs" do
    it "persists a new active CV from text" do
      post cvs_path, params: { cv: { body_text: "Contenu" } }

      expect(response).to redirect_to(cvs_path)
      follow_redirect!

      expect(response.body).to include("Votre CV principal a été mis à jour.")
      expect(user.reload.active_cv).to be_present
    end

    it "re-renders the form when invalid" do
      post cvs_path, params: { cv: { body_text: "" } }

      expect(response).to have_http_status(:unprocessable_entity)
      expect(response.body).to include("Le CV doit contenir du texte")
    end
  end
end
