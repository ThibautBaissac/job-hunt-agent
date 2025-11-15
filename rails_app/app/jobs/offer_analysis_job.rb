class OfferAnalysisJob < ApplicationJob
  queue_as :default

  def perform(job_offer_id)
    job_offer = JobOffer.find(job_offer_id)
    return unless analyzer_available?

    Ai::OfferAnalyzer.new(job_offer: job_offer).call
  rescue ActiveRecord::RecordNotFound
    Rails.logger.info("OfferAnalysisJob: JobOffer ##{job_offer_id} introuvable, abandon.")
  rescue Ai::OfferAnalyzer::NotConfigured => e
    Rails.logger.info("OfferAnalysisJob ignoré : #{e.message}")
  rescue Ai::OfferAnalyzer::Error => e
    Rails.logger.error("Analyse d'offre impossible : #{e.message}")
  end

  private

  def analyzer_available?
    defined?(Ai::OfferAnalyzer)
  end
end
