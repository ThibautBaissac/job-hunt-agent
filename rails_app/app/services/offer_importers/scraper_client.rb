require "json"
require "faraday"

module OfferImporters
  class ScraperClient
    class Error < StandardError; end

    def initialize(base_url: default_base_url, connection: nil)
      @base_url = base_url
      @connection = connection
    end

    def fetch(url)
      response = connection.post("/scrape/offer") do |req|
        req.headers["Content-Type"] = "application/json"
        req.body = { url: url }.to_json
      end

      handle_response(response)
    rescue Faraday::Error => e
      raise Error, "Scraper API indisponible : #{e.message}"
    end

    private

    attr_reader :base_url

    def connection
      @connection ||= Faraday.new(url: base_url) do |faraday|
        faraday.response :raise_error
        faraday.adapter Faraday.default_adapter
      end
    end

    def handle_response(response)
      body = parse_body(response.body)

      {
        title: body.fetch("title", nil)&.to_s,
        company: body.fetch("company", nil)&.to_s,
        location: body.fetch("location", nil)&.to_s,
        description: body.fetch("description", nil)&.to_s,
        platform: body.fetch("platform", nil)&.to_s
      }
    rescue KeyError => e
      raise Error, "Réponse invalide du Scraper API : #{e.message}"
    end

    def parse_body(payload)
      case payload
      when String
        JSON.parse(payload)
      when Hash
        payload
      else
        raise Error, "Réponse inconnue du Scraper API"
      end
    rescue JSON::ParserError
      raise Error, "Réponse illisible du Scraper API"
    end

    def default_base_url
      ENV.fetch("SCRAPER_API_URL") do
        raise Error, "SCRAPER_API_URL manquant dans la configuration"
      end
    end
  end
end
