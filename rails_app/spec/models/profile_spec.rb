# frozen_string_literal: true

require "rails_helper"

RSpec.describe Profile, type: :model do
  describe "associations" do
    it { is_expected.to belong_to(:user) }
  end

  describe "enums" do
    it "exposes the expected language options" do
      expect(described_class.languages).to eq(Profile::LANGUAGE_OPTIONS.transform_keys(&:to_s))
    end

    it "exposes the expected AI tone options" do
      expect(described_class.ai_tones).to eq(Profile::AI_TONE_OPTIONS.transform_keys(&:to_s))
    end
  end

  describe "validations" do
    it { is_expected.to allow_value("https://github.com/example").for(:github_url) }
    it { is_expected.to allow_value("https://www.linkedin.com/in/example").for(:linkedin_url) }
    it { is_expected.to allow_value(nil).for(:github_url) }
    it { is_expected.to allow_value(nil).for(:linkedin_url) }
    it { is_expected.not_to allow_value("invalid").for(:github_url) }
    it { is_expected.not_to allow_value("invalid").for(:linkedin_url) }
  end

  describe "defaults" do
    it "assigns language and ai tone defaults" do
      profile = create(:user).profile

      expect(profile.language).to eq("french")
      expect(profile.ai_tone).to eq("neutral")
    end
  end
end
