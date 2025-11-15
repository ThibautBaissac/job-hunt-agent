require "rails_helper"

RSpec.describe JobOffer, type: :model do
  it { is_expected.to belong_to(:user) }
  it { is_expected.to validate_presence_of(:title) }
  it { is_expected.to validate_presence_of(:company_name) }
  it { is_expected.to validate_presence_of(:raw_description) }
  it "defines the expected sources" do
    expect(described_class.sources).to eq(
      "linkedin" => "linkedin",
      "wttj" => "wttj",
      "other" => "other"
    )
  end

  describe "scopes" do
    describe ".recent_first" do
      it "returns offers ordered from newest to oldest" do
        older = create(:job_offer, created_at: 2.days.ago)
        newer = create(:job_offer, created_at: 1.day.ago)

        ordered = described_class.recent_first.where(id: [ newer.id, older.id ])

        expect(ordered).to eq([ newer, older ])
      end
    end
  end

  describe "#analysis_available?" do
    it "returns true when analyzed_at and summary are present" do
      job_offer = build(:job_offer, summary: "Résumé", analyzed_at: Time.current)

      expect(job_offer.analysis_available?).to be(true)
    end

    it "returns false otherwise" do
      job_offer = build(:job_offer, summary: nil, analyzed_at: nil)

      expect(job_offer.analysis_available?).to be(false)
    end
  end

  describe "#tech_stack" do
    it "returns an empty array when nil" do
      job_offer = build(:job_offer, tech_stack: nil)

      expect(job_offer.tech_stack).to eq([])
    end
  end
end
