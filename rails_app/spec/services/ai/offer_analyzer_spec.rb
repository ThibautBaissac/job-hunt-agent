require "rails_helper"

RSpec.describe Ai::OfferAnalyzer do
  let(:job_offer) { create(:job_offer) }
  let(:chat) { instance_double(RubyLLM::Chat) }
  let(:client) { instance_double(Ai::Client, chat: chat) }
  let(:response_payload) do
    {
      summary: "Poste de développeur senior Ruby on Rails dans une scale-up.",
      tech_stack: [ "Ruby on Rails", "PostgreSQL", "Redis", "React" ],
      keywords: [ "télétravail", "scale-up", "API REST", "agile" ],
      seniority_level: "Senior"
    }
  end
  let(:response_message) { instance_double(RubyLLM::Message, content: response_payload) }

  before do
    allow(chat).to receive(:with_instructions).and_return(chat)
    allow(chat).to receive(:with_schema).and_return(chat)
    allow(chat).to receive(:with_temperature).and_return(chat)
  end

  describe "#call" do
    it "persists the analysis on the job offer" do
      allow(chat).to receive(:ask).and_return(response_message)

      described_class.new(job_offer: job_offer, client: client).call

      job_offer.reload
      expect(job_offer.summary).to eq("Poste de développeur senior Ruby on Rails dans une scale-up.")
      expect(job_offer.tech_stack).to include("Ruby on Rails", "PostgreSQL")
      expect(job_offer.keywords).to include("télétravail", "scale-up")
      expect(job_offer.seniority_level).to eq("Senior")
      expect(job_offer.analyzed_at).to be_present
    end

    it "handles markdown fences and prose" do
      fenced_payload = <<~JSON
        Voici l'analyse de l'offre :

        ```json
        {"summary":"Poste backend","tech_stack":["Ruby"],"keywords":["remote"],"seniority_level":"Junior"}
        ```
      JSON
      fenced_response = instance_double(RubyLLM::Message, content: fenced_payload)

      allow(chat).to receive(:ask).and_return(fenced_response)

      described_class.new(job_offer: job_offer, client: client).call

      expect(job_offer.reload.summary).to eq("Poste backend")
      expect(job_offer.tech_stack).to eq([ "Ruby" ])
    end

    it "falls back to streamed buffer when response content is not directly usable" do
      raw_stream = <<~JSON
        ```json
        {"summary":"Fallback","tech_stack":["Node.js"],"keywords":["startup"],"seniority_level":"Mid"}
        ```
      JSON

      chunk = instance_double(RubyLLM::Chunk, content: raw_stream)
      message = instance_double(RubyLLM::Message, content: Object.new)

      expect(chat).to receive(:ask) do |&block|
        block.call(chunk)
        message
      end

      described_class.new(job_offer: job_offer, client: client).call

      job_offer.reload
      expect(job_offer.summary).to eq("Fallback")
      expect(job_offer.tech_stack).to eq([ "Node.js" ])
    end

    it "streams chunks when provided" do
      chunk = instance_double(RubyLLM::Chunk, content: "token ")
      streamed = []

      expect(chat).to receive(:ask) do |&block|
        block.call(chunk)
        response_message
      end

      described_class.new(job_offer: job_offer, client: client, streamer: ->(content) { streamed << content }).call

      expect(streamed).to eq([ "token " ])
    end

    it "raises an error when response cannot be parsed" do
      allow(chat).to receive(:ask).and_return(instance_double(RubyLLM::Message, content: "not-json"))

      expect {
        described_class.new(job_offer: job_offer, client: client).call
      }.to raise_error(Ai::OfferAnalyzer::Error)
    end
  end
end
