require "rails_helper"

RSpec.describe Ai::CvAnalyzer do
  let(:cv) { create(:cv, :active) }
  let(:chat) { instance_double(RubyLLM::Chat) }
  let(:client) { instance_double(Ai::Client, chat: chat) }
  let(:response_payload) do
    {
      summary: "Profil solide pour un poste backend.",
      strengths: [ "Maîtrise de Ruby on Rails", "Expérience en API" ],
      weaknesses: [ "Peu de tests end-to-end" ],
      suggestions: [ "Mettre en avant les résultats chiffrés" ]
    }
  end
  let(:response_message) { instance_double(RubyLLM::Message, content: response_payload) }

  before do
    allow(chat).to receive(:with_instructions).and_return(chat)
    allow(chat).to receive(:with_schema).and_return(chat)
    allow(chat).to receive(:with_temperature).and_return(chat)
  end

  describe "#call" do
    it "persists the analysis on the CV" do
      allow(chat).to receive(:ask).and_return(response_message)

      described_class.new(cv: cv, client: client).call

      cv.reload
      expect(cv.analysis_summary).to eq("Profil solide pour un poste backend.")
      expect(cv.analysis_forces).to include("Maîtrise de Ruby on Rails")
      expect(cv.analyzed_at).to be_present
    end

    it "handles markdown fences and prose" do
      fenced_payload = <<~JSON
        Voici l'analyse du CV selon le schéma demandé :

        ```json
        {"summary":"Profil","strengths":[],"weaknesses":[],"suggestions":[]}
        ```
      JSON
      fenced_response = instance_double(RubyLLM::Message, content: fenced_payload)

      allow(chat).to receive(:ask).and_return(fenced_response)

      described_class.new(cv: cv, client: client).call

      expect(cv.reload.analysis_summary).to eq("Profil")
    end

    it "falls back to streamed buffer when response content is not directly usable" do
      raw_stream = <<~JSON
        ```json
        {"summary":"Fallback","strengths":["A"],"weaknesses":["B"],"suggestions":["C"]}
        ```
      JSON

      chunk = instance_double(RubyLLM::Chunk, content: raw_stream)
      message = instance_double(RubyLLM::Message, content: Object.new)

      expect(chat).to receive(:ask) do |&block|
        block.call(chunk)
        message
      end

      described_class.new(cv: cv, client: client).call

      cv.reload
      expect(cv.analysis_summary).to eq("Fallback")
      expect(cv.analysis_forces).to eq([ "A" ])
    end

    it "streams chunks when provided" do
      chunk = instance_double(RubyLLM::Chunk, content: "token ")
      streamed = []

      expect(chat).to receive(:ask) do |&block|
        block.call(chunk)
        response_message
      end

      described_class.new(cv: cv, client: client, streamer: ->(content) { streamed << content }).call

      expect(streamed).to eq([ "token " ])
    end

    it "raises an error when response cannot be parsed" do
      allow(chat).to receive(:ask).and_return(instance_double(RubyLLM::Message, content: "not-json"))

      expect {
        described_class.new(cv: cv, client: client).call
      }.to raise_error(Ai::CvAnalyzer::Error)
    end
  end
end
