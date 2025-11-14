# frozen_string_literal: true

require "rails_helper"

RSpec.describe Integrations::GmailClient do
  before do
    allow(ENV).to receive(:fetch).and_call_original
    allow(ENV).to receive(:fetch).with("GOOGLE_CLIENT_ID").and_return("client-id")
    allow(ENV).to receive(:fetch).with("GOOGLE_CLIENT_SECRET").and_return("client-secret")
  end

  let(:client_options) { double("ClientOptions", application_name: nil) }
  let(:gmail_service) { instance_double(Google::Apis::GmailV1::GmailService, client_options: client_options) }
  let(:auth_client) { instance_double(Signet::OAuth2::Client) }

  before do
    allow(client_options).to receive(:application_name=)
    allow(gmail_service).to receive(:authorization=)
    allow(Google::Apis::GmailV1::GmailService).to receive(:new).and_return(gmail_service)
    allow(Signet::OAuth2::Client).to receive(:new).and_return(auth_client)
    allow(auth_client).to receive(:refresh_token).and_return("refresh-token")
    allow(auth_client).to receive(:access_token).and_return("access-token")
    allow(auth_client).to receive(:expires_at).and_return(1.hour.from_now.to_i)
    allow(auth_client).to receive(:refresh!)
  end

  describe "#initialize" do
    it "raises an error when Gmail is not connected" do
      user = build(:user, gmail_connected: false)

      expect { described_class.new(user) }.to raise_error(described_class::NotConnectedError)
    end
  end

  describe "#send_email" do
    let(:user) do
      create(
        :user,
        gmail_connected: true,
        google_access_token: "access-token",
        google_refresh_token: "refresh-token",
        google_token_expires_at: expires_at
      )
    end
    let(:expires_at) { 1.hour.from_now }
    let(:client) { described_class.new(user) }

    it "delivers the message through Gmail API" do
      response = double(id: "abc", thread_id: "thread", label_ids: ["SENT"])
      expect(gmail_service).to receive(:send_user_message).with("me", instance_of(Google::Apis::GmailV1::Message)).and_return(response)

      result = client.send_email(to: "target@example.com", subject: "Hello", body: "<p>Body</p>")

      expect(result).to eq(external_id: "abc", thread_id: "thread", label_ids: ["SENT"])
    end

    it "refreshes the token when expired" do
      user.update!(google_token_expires_at: 1.hour.ago)
      allow(auth_client).to receive(:expires_at).and_return(2.hours.from_now.to_i)
      allow(auth_client).to receive(:access_token).and_return("new-access")

      allow(gmail_service).to receive(:send_user_message).and_return(double(id: "1", thread_id: "2", label_ids: []))

      expect(auth_client).to receive(:refresh!)

      client.send_email(to: "target@example.com", subject: "Hi", body: "<p>Body</p>")

      expect(user.reload.google_access_token).to eq("new-access")
      expect(gmail_service).to have_received(:authorization=).with(auth_client).at_least(:once)
    end

    it "disconnects and raises when the API returns an authorization error" do
      error = Google::Apis::AuthorizationError.new("auth failed")
      allow(gmail_service).to receive(:send_user_message).and_raise(error)

      expect do
        client.send_email(to: "target@example.com", subject: "Hi", body: "<p>Body</p>")
      end.to raise_error(described_class::TokenExpiredError)

      expect(user.reload.gmail_connected?).to be(false)
    end

    it "raises a send error when Gmail API fails" do
      error_class = Class.new(Google::Apis::Error)
      allow(gmail_service).to receive(:send_user_message).and_raise(error_class.new("boom"))

      expect do
        client.send_email(to: "target@example.com", subject: "Hi", body: "<p>Body</p>")
      end.to raise_error(described_class::SendError)
    end

    it "handles refresh token failures" do
      user.update!(google_token_expires_at: 1.hour.ago)
      allow(auth_client).to receive(:refresh!).and_raise(Signet::AuthorizationError.new("invalid"))

      expect do
        client.send_email(to: "target@example.com", subject: "Hi", body: "<p>Body</p>")
      end.to raise_error(described_class::TokenExpiredError)

      user.reload
      expect(user.gmail_connected?).to be(false)
      expect(user.google_access_token).to be_nil
    end
  end
end
