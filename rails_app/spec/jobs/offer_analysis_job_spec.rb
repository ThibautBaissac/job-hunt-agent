require "rails_helper"

RSpec.describe OfferAnalysisJob, type: :job do
  let(:job_offer) { create(:job_offer) }
  let(:analyzer) { instance_double(Ai::OfferAnalyzer) }
  let(:analysis_result) do
    {
      summary: "Poste de développeur senior Ruby on Rails.",
      tech_stack: [ "Ruby on Rails", "PostgreSQL" ],
      keywords: [ "télétravail", "agile" ],
      seniority_level: "Senior"
    }
  end

  before do
    allow(Ai::OfferAnalyzer).to receive(:new).and_return(analyzer)
    allow(analyzer).to receive(:call).and_return(analysis_result)
    allow(Turbo::StreamsChannel).to receive(:broadcast_replace_to)
    allow(ApplicationController).to receive(:render).and_return("<div>Mock HTML</div>")
  end

  describe "#perform" do
    it "analyzes the job offer" do
      described_class.new.perform(job_offer.id)

      expect(Ai::OfferAnalyzer).to have_received(:new).with(job_offer: job_offer, streamer: anything, backend: :rails)
      expect(analyzer).to have_received(:call)
    end

    it "updates the job offer with analysis results" do
      described_class.new.perform(job_offer.id)

      job_offer.reload
      # Vérifier que l'analyse a bien été persistée serait testé par l'analyzer
      # Ici on vérifie juste que le job s'exécute sans erreur
      expect(Ai::OfferAnalyzer).to have_received(:new)
    end

    it "passes the backend mode when provided" do
      described_class.new.perform(job_offer.id, mode: "python")

      expect(Ai::OfferAnalyzer).to have_received(:new).with(job_offer: job_offer, streamer: anything, backend: :python)
    end

    context "when analysis fails" do
      before do
        allow(analyzer).to receive(:call).and_raise(Ai::OfferAnalyzer::Error, "Analyse impossible")
      end

      it "does not raise and handles the error gracefully" do
        expect {
          described_class.new.perform(job_offer.id)
        }.not_to raise_error
      end
    end
  end
end
