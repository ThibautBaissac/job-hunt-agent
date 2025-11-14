# frozen_string_literal: true

require "rails_helper"

RSpec.describe User, type: :model do
  describe "associations" do
    it { is_expected.to have_one(:profile).dependent(:destroy) }
  end

  describe "callbacks" do
    it "creates a profile after creation" do
      expect { create(:user) }.to change(Profile, :count).by(1)
    end
  end

  describe "#gmail_connected?" do
    it "returns false when the flag is false" do
      user = build(:user, gmail_connected: false, google_access_token: nil)

      expect(user.gmail_connected?).to be(false)
    end

    it "returns true when connected and the token is present" do
      user = build(:user, gmail_connected: true, google_access_token: "token")

      expect(user.gmail_connected?).to be(true)
    end
  end

  describe "#google_token_expired?" do
    it "returns false when no expiry is stored" do
      user = build(:user, google_token_expires_at: nil)

      expect(user.google_token_expired?).to be(false)
    end

    it "returns false when the expiry is in the future" do
      user = build(:user, google_token_expires_at: 1.hour.from_now)

      expect(user.google_token_expired?).to be(false)
    end

    it "returns true when the expiry is in the past" do
      user = build(:user, google_token_expires_at: 1.hour.ago)

      expect(user.google_token_expired?).to be(true)
    end
  end

  describe "#gmail_needs_reconnect?" do
    it "returns false when the account is not connected" do
      user = build(:user, gmail_connected: false, google_access_token: nil)

      expect(user.gmail_needs_reconnect?).to be(false)
    end

    it "returns false when the token is not expired" do
      user = build(:user, gmail_connected: true, google_access_token: "token", google_token_expires_at: 1.hour.from_now)

      expect(user.gmail_needs_reconnect?).to be(false)
    end

    it "returns true when the token has expired" do
      user = build(:user, gmail_connected: true, google_access_token: "token", google_token_expires_at: 1.hour.ago)

      expect(user.gmail_needs_reconnect?).to be(true)
    end
  end

  describe "#disconnect_gmail!" do
    it "clears Gmail related data" do
      user = create(
        :user,
        gmail_connected: true,
        google_uid: "uid",
        google_access_token: "access",
        google_refresh_token: "refresh",
        google_token_expires_at: 1.hour.from_now
      )

      user.disconnect_gmail!
      user.reload

      expect(user.gmail_connected?).to be(false)
      expect(user.google_uid).to be_nil
      expect(user.google_access_token).to be_nil
      expect(user.google_refresh_token).to be_nil
      expect(user.google_token_expires_at).to be_nil
    end
  end

  describe ".connect_google_account!" do
    it "updates the user with credentials from OmniAuth" do
      user = create(:user)
      credentials = Struct.new(:token, :refresh_token, :expires_at).new("token", "refresh", 1.hour.from_now.to_i)
      auth = Struct.new(:uid, :credentials).new("123", credentials)

      described_class.connect_google_account!(user: user, auth: auth)
      user.reload

      expect(user.google_uid).to eq("123")
      expect(user.gmail_connected?).to be(true)
      expect(user.google_access_token).to eq("token")
      expect(user.google_refresh_token).to eq("refresh")
      expect(user.google_token_expires_at.to_i).to eq(Time.at(credentials.expires_at).to_i)
    end

    it "preserves the existing refresh token when none is provided" do
      user = create(:user, google_refresh_token: "persisted")
      credentials = Struct.new(:token, :refresh_token, :expires_at).new("token", nil, nil)
      auth = Struct.new(:uid, :credentials).new("123", credentials)

      described_class.connect_google_account!(user: user, auth: auth)
      user.reload

      expect(user.google_refresh_token).to eq("persisted")
    end
  end
end
