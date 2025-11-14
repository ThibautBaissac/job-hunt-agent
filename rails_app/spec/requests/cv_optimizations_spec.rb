require "rails_helper"
require "warden/test/helpers"

RSpec.describe "CvOptimizations", type: :request do
  include Warden::Test::Helpers

  let(:user) { create(:user) }
  let!(:cv) { create(:cv, :active, :analyzed, user: user) }

  before do
    login_as(user, scope: :user)
  end

  after do
    Warden.test_reset!
  end

  describe "GET /cvs/:cv_id/optimizations/new" do
    it "renders the form" do
      get new_cv_optimization_path(cv)

      expect(response).to have_http_status(:ok)
      expect(response.body).to include("Créer une version optimisée")
    end
  end

  describe "POST /cvs/:cv_id/optimizations" do
    it "creates a new optimized CV" do
      expect do
        post cv_optimizations_path(cv), params: { optimization: { body_text: "Version améliorée" } }
      end.to change { user.cvs.count }.by(1)

      expect(response).to redirect_to(cvs_path)
      follow_redirect!
      expect(response.body).to include("nouvelle version optimisée")
    end
  end
end
