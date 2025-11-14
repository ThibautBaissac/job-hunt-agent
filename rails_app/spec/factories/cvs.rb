FactoryBot.define do
  factory :cv do
    association :user
    body_text { "Expérience professionnelle : développeur Ruby" }
    import_method { "paste" }
    active { false }
    source_filename { nil }

    trait :active do
      active { true }
    end

    trait :upload do
      import_method { "upload" }
      source_filename { "cv.pdf" }
    end
  end
end
