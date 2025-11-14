require "rails_helper"

RSpec.describe CvVersions::Activate do
  let(:user) { create(:user) }
  let!(:active_cv) { create(:cv, :active, user: user) }
  let!(:other_cv) { create(:cv, user: user) }

  it "sets the selected CV as active" do
    described_class.new(user: user, cv: other_cv).call

    expect(other_cv.reload).to be_active
    expect(active_cv.reload).not_to be_active
  end

  it "raises when the CV does not belong to the user" do
    outsider_cv = create(:cv)

    expect {
      described_class.new(user: user, cv: outsider_cv).call
    }.to raise_error(CvVersions::Activate::Error)
  end
end
