class Cv < ApplicationRecord
  IMPORT_METHODS = %w[paste upload].freeze

  belongs_to :user
  has_one_attached :document

  validates :body_text, presence: true
  validates :import_method, inclusion: { in: IMPORT_METHODS }

  scope :recent_first, -> { order(created_at: :desc) }
end
