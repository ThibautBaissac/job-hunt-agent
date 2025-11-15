require "rails_helper"

RSpec.describe OfferImporters::CreateFromUrl do
  let(:user) { create(:user) }
  let(:url) { "https://www.linkedin.com/jobs/view/123" }
  let(:scraper_client) { instance_double(OfferImporters::ScraperClient) }
  let(:service) { described_class.new(user: user, url: url, scraper_client: scraper_client) }
  let(:payload) do
    {
      title: "Senior Ruby Developer",
      company: "ACME",
      location: "Paris",
      description: "Développer des applications Ruby",
      platform: "linkedin"
    }
  end

  around do |example|
    original_adapter = ActiveJob::Base.queue_adapter
    ActiveJob::Base.queue_adapter = :test
    clear_enqueued_jobs
    example.run
  ensure
    clear_enqueued_jobs
    ActiveJob::Base.queue_adapter = original_adapter
  end

  describe "#call" do
    it "creates a job offer and enqueues analysis" do
      allow(scraper_client).to receive(:fetch).with(url).and_return(payload)

      job_offer = nil

      expect {
        job_offer = service.call
        expect(job_offer.title).to eq("Senior Ruby Developer")
        expect(job_offer.company_name).to eq("ACME")
        expect(job_offer.source).to eq("linkedin")
      }.to change(JobOffer, :count).by(1)

      enqueued_job = enqueued_jobs.find { |job| job[:job] == OfferAnalysisJob }
      expect(enqueued_job).to be_present
      expect(enqueued_job[:args]).to eq([ job_offer.id ])
    end

    it "raises an error when payload is incomplete" do
      allow(scraper_client).to receive(:fetch).and_return(payload.merge(title: ""))

      expect {
        service.call
      }.to raise_error(described_class::Error)
    end

    it "wraps scraper client errors" do
      allow(scraper_client).to receive(:fetch).and_raise(OfferImporters::ScraperClient::Error, "timeout")

      expect {
        service.call
      }.to raise_error(described_class::Error, /timeout/)
    end
  end
end
