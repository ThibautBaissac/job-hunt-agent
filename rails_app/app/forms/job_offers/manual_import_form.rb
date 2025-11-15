module JobOffers
  class ManualImportForm
    include ActiveModel::Model

    attr_accessor :title, :company_name, :location, :raw_description, :source_url, :tech_stack_input
    attr_reader :job_offer

    validates :title, presence: { message: "doit être renseigné" }
    validates :company_name, presence: { message: "doit être renseigné" }
    validates :raw_description, presence: { message: "doit être renseignée" }
    validates :source_url, allow_blank: true, format: {
      with: URI::DEFAULT_PARSER.make_regexp(%w[http https]),
      message: "n'est pas une URL valide"
    }

    def initialize(user:, attributes: {})
      @user = user
      super(attributes)
    end

    def submit
      return false unless valid?

      @job_offer = user.job_offers.create!(
        title: title,
        company_name: company_name,
        location: location,
        raw_description: raw_description,
        source_url: source_url.presence,
        source: "other",
        tech_stack: parse_tech_stack
      )

      # Queue async analysis job
      OfferAnalysisJob.perform_later(@job_offer.id)

      true
    rescue ActiveRecord::RecordInvalid => e
      errors.add(:base, "Erreur lors de la création de l'offre : #{e.message}")
      false
    end

    private

    attr_reader :user

    def parse_tech_stack
      return [] if tech_stack_input.blank?

      # Split by comma, semicolon, or newline and clean up
      tech_stack_input
        .split(/[,;\n]/)
        .map(&:strip)
        .reject(&:blank?)
    end
  end
end
