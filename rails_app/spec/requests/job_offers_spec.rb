require "rails_helper"

RSpec.describe "JobOffers", type: :request do
  let(:user) { create(:user) }

  before { sign_in(user, scope: :user) }

  describe "GET /job_offers/new" do
    it "returns success" do
      get new_job_offer_path

      expect(response).to have_http_status(:ok)
    end
  end

  describe "POST /job_offers" do
    let(:url) { "https://www.linkedin.com/jobs/view/123" }
    let(:params) { { job_offer_import: { url: url } } }

    context "when import succeeds" do
      let(:job_offer) { create(:job_offer, user: user) }

      it "redirects to the job offer page" do
        service = instance_double(OfferImporters::CreateFromUrl, call: job_offer)
        allow(OfferImporters::CreateFromUrl).to receive(:new)
          .with(user: user, url: url, scraper_client: nil)
          .and_return(service)

        post job_offers_path, params: params

        expect(response).to redirect_to(job_offer_path(job_offer))
        expect(flash[:notice]).to eq("Offre importée avec succès.")
      end
    end

    context "when import fails" do
      it "re-renders the form with errors" do
        service = instance_double(OfferImporters::CreateFromUrl)
        allow(service).to receive(:call).and_raise(OfferImporters::CreateFromUrl::Error, "Erreur")
        allow(OfferImporters::CreateFromUrl).to receive(:new)
          .with(user: user, url: url, scraper_client: nil)
          .and_return(service)

        post job_offers_path, params: params

        expect(response).to have_http_status(:unprocessable_entity)
        expect(response.body).to include("Erreur")
      end
    end
  end

  describe "POST /job_offers/:id/analyze" do
    let(:job_offer) { create(:job_offer, user: user) }

    around do |example|
      original_adapter = ActiveJob::Base.queue_adapter
      ActiveJob::Base.queue_adapter = :test
      example.run
      ActiveJob::Base.queue_adapter = original_adapter
    end

    it "enqueues an offer analysis job and streams loading state" do
      expect do
        post analyze_job_offer_path(job_offer),
             headers: default_headers("Accept" => "text/vnd.turbo-stream.html"),
             params: {}
      end.to have_enqueued_job(OfferAnalysisJob).with(job_offer.id)

      expect(response).to have_http_status(:ok)
      expect(response.media_type).to eq("text/vnd.turbo-stream.html")
      expect(response.body).to include("Analyse en cours")
    end

    it "redirects with a notice for HTML requests" do
      post analyze_job_offer_path(job_offer)

      expect(response).to redirect_to(job_offer_path(job_offer))
      expect(flash[:notice]).to include("Analyse relancée")
    end
  end
end
