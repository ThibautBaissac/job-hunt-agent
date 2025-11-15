module JobOffers
  class UrlImportForm
    include ActiveModel::Model

    attr_accessor :url
    attr_reader :job_offer

    validates :url, presence: { message: "doit être renseignée" }
    validates :url, format: {
      with: URI::DEFAULT_PARSER.make_regexp(%w[http https]),
      allow_blank: true,
      message: "n'est pas une URL valide"
    }

    def initialize(user:, attributes: {}, scraper_client: nil)
      @user = user
      @scraper_client = scraper_client
      super(attributes)
    end

    def submit
      return false unless valid?

      @job_offer = OfferImporters::CreateFromUrl.new(
        user: user,
        url: url,
        scraper_client: scraper_client
      ).call
      true
    rescue OfferImporters::CreateFromUrl::Error => e
      errors.add(:base, e.message)
      false
    end

    private

    attr_reader :user, :scraper_client
  end
end
