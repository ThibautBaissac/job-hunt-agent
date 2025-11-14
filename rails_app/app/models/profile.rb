require "uri"

class Profile < ApplicationRecord
  belongs_to :user

  LANGUAGE_OPTIONS = {
    french: "fr",
    english: "en"
  }.freeze

  AI_TONE_OPTIONS = {
    neutral: "neutral",
    friendly: "friendly",
    formal: "formal",
    energetic: "energetic"
  }.freeze

  enum :language, LANGUAGE_OPTIONS, suffix: true
  enum :ai_tone, AI_TONE_OPTIONS, suffix: true

  validates :github_url, :linkedin_url,
            format: { with: URI::DEFAULT_PARSER.make_regexp(%w[http https]) },
            allow_blank: true
end
