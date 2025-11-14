require "rails_helper"

RSpec.describe Cv, type: :model do
  it { is_expected.to belong_to(:user) }
  it { is_expected.to validate_presence_of(:body_text) }
  it { is_expected.to validate_inclusion_of(:import_method).in_array(%w[paste upload]) }
  it { is_expected.to have_one_attached(:document) }

  describe ".recent_first" do
    it "orders CVs from newest to oldest" do
      older = create(:cv, created_at: 2.days.ago)
      newer = create(:cv, created_at: 1.day.ago)

      expect(described_class.recent_first).to eq([ newer, older ])
    end
  end
end
