FactoryBot.define do
  factory :job_offer do
    association :user
    source { "linkedin" }
    source_url { "https://example.com/offre" }
    title { "Développeur Ruby" }
    company_name { "Example Corp" }
    location { "Paris" }
    contract_type { "CDI" }
    seniority_level { "Intermédiaire" }
    raw_description { "Description détaillée du poste." }
    tech_stack { [] }

    trait :analyzed do
      summary { "Poste technique orienté backend." }
      tech_stack { [ "Ruby", "Rails" ] }
      analyzed_at { Time.current }
    end
  end
end
