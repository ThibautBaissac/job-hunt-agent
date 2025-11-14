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

  describe "GET /cvs/:id" do
    let(:cv) { create(:cv, user: user, analysis_summary: "Résumé", analyzed_at: Time.current) }

    it "shows the CV details" do
      get cv_path(cv)

      expect(response).to have_http_status(:ok)
      expect(response.body).to include(cv.display_name)
      expect(response.body).to include("Analyse IA")
    end

    it "returns not found for another user" do
      other_cv = create(:cv)

      get cv_path(other_cv)

      expect(response).to have_http_status(:not_found)
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

  describe "POST /cvs/:id/analyze" do
    let(:cv) { create(:cv, :active, user: user) }

    before do
      ActiveJob::Base.queue_adapter = :test
    end

    it "enqueues an analysis job" do
      expect do
        post analyze_cv_path(cv), headers: default_headers("Accept" => "text/vnd.turbo-stream.html"), params: {}
      end.to have_enqueued_job(CvAnalysisJob).with(cv.id)
    end
  end

  describe "POST /cvs/:id/activate" do
    let!(:active_cv) { create(:cv, :active, user: user) }
    let!(:other_cv) { create(:cv, user: user) }

    it "switches the active version" do
      post activate_cv_path(other_cv)

      expect(response).to redirect_to(cvs_path)
      expect(user.reload.active_cv).to eq(other_cv)
    end
  end
end
