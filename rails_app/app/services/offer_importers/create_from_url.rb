module OfferImporters
  class CreateFromUrl
    class Error < StandardError; end

    def initialize(user:, url:, scraper_client: nil)
      @user = user
      @url = url
      @scraper_client = scraper_client || ScraperClient.new
    end

    def call
      payload = scraper_client.fetch(url)
      ensure_payload_valid!(payload)

      job_offer = user.job_offers.create!(mapped_attributes(payload))
      OfferAnalysisJob.perform_later(job_offer.id)
      job_offer
    rescue OfferImporters::ScraperClient::Error => e
      raise Error, e.message
    rescue ActiveRecord::RecordInvalid => e
      raise Error, e.record.errors.full_messages.to_sentence
    end

    private

    attr_reader :user, :url, :scraper_client

    def ensure_payload_valid!(payload)
      if payload[:title].blank? || payload[:company].blank? || payload[:description].blank?
        raise Error, "L'offre récupérée est incomplète. Veuillez utiliser l'import manuel."
      end
    end

    def mapped_attributes(payload)
      {
        source: normalize_platform(payload[:platform]),
        source_url: url,
        title: payload[:title],
        company_name: payload[:company],
        location: payload[:location],
        raw_description: payload[:description]
      }
    end

    def normalize_platform(platform)
      normalized = platform.to_s.downcase
      return normalized if JobOffer::SOURCES.include?(normalized)

      "other"
    end
  end
end
