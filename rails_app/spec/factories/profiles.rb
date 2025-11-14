# frozen_string_literal: true

FactoryBot.define do
  factory :profile do
    association :user
    full_name { "Jane Doe" }
    title { "Software Engineer" }
    city { "Paris" }
    language { Profile::LANGUAGE_OPTIONS[:french] }
    ai_tone { Profile::AI_TONE_OPTIONS[:neutral] }
  end
end
