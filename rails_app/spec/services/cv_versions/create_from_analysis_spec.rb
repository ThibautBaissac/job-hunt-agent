require "rails_helper"

RSpec.describe CvVersions::CreateFromAnalysis do
  let(:user) { create(:user) }
  let!(:current_cv) { create(:cv, :active, user: user) }

  describe "#call" do
    it "creates a new active CV" do
      params = { body_text: "Nouveau contenu" }

      expect do
        described_class.new(user: user, source_cv: current_cv, params: params).call
      end.to change { user.cvs.count }.by(1)

      expect(user.reload.active_cv.body_text).to eq("Nouveau contenu")
    end

    it "raises an error when body_text is empty" do
      expect do
        described_class.new(user: user, source_cv: current_cv, params: { body_text: "" }).call
      end.to raise_error(CvVersions::CreateFromAnalysis::Error)
    end
  end
end
