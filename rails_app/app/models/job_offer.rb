class JobOffer < ApplicationRecord
  SOURCES = %w[linkedin wttj other].freeze

  belongs_to :user

  enum :source, SOURCES.index_with(&:to_s)

  validates :title, presence: true
  validates :company_name, presence: true
  validates :raw_description, presence: true
  validates :source, inclusion: { in: SOURCES }
  validates :source_url, allow_blank: true, format: {
    with: URI::DEFAULT_PARSER.make_regexp(%w[http https]),
    message: "n'est pas une URL valide"
  }

  scope :recent_first, -> { order(created_at: :desc) }

  def analysis_available?
    analyzed_at.present? && summary.present?
  end

  def tech_stack
    super || []
  end
end
