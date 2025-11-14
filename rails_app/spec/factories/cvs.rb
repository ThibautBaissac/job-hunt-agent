FactoryBot.define do
  factory :cv do
    association :user
    body_text { "Expérience professionnelle : développeur Ruby" }
    import_method { "paste" }
    active { false }
    source_filename { nil }
    title { "CV principal" }

    trait :active do
      active { true }
    end

    trait :upload do
      import_method { "upload" }
      source_filename { "cv.pdf" }
    end

    trait :analyzed do
      analysis_summary { "Excellent profil backend avec expérience Rails." }
      analysis_forces { [ "10 ans d'expérience Ruby", "Expérience DevOps" ] }
      analysis_weaknesses { [ "Peu de projets front" ] }
      analysis_suggestions { [ "Ajouter des chiffres sur les résultats obtenus" ] }
      analyzed_at { Time.current }
    end
  end
end
