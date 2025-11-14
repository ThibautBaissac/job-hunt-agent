class Cv < ApplicationRecord
  IMPORT_METHODS = %w[paste upload].freeze

  belongs_to :user
  has_one_attached :document

  validates :body_text, presence: true
  validates :import_method, inclusion: { in: IMPORT_METHODS }
  validates :title, length: { maximum: 255 }, allow_blank: true

  scope :recent_first, -> { order(created_at: :desc) }

  def display_name
    title.presence || source_filename.presence || "Import texte"
  end

  def analysis_available?
    analyzed_at.present? && (
      analysis_summary.present? || analysis_forces.any? || analysis_weaknesses.any? || analysis_suggestions.any?
    )
  end

  def analysis_forces
    super || []
  end

  def analysis_weaknesses
    super || []
  end

  def analysis_suggestions
    super || []
  end
end
