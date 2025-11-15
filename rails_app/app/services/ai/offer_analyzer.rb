module Ai
  class OfferAnalyzer
    class Error < StandardError; end
    class NotConfigured < Error; end

    def initialize(job_offer:, client: nil)
      @job_offer = job_offer
      @client = client
    end

    def call
      raise NotConfigured, "Agent API non configurée pour l'analyse d'offre."
    end

    private

    attr_reader :job_offer, :client
  end
end
