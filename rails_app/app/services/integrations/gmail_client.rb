# frozen_string_literal: true

require "base64"
require "google/apis/gmail_v1"
require "googleauth"
require "mail"

module Integrations
  class GmailClient
    class Error < StandardError; end
    class NotConnectedError < Error; end
    class TokenExpiredError < Error; end
    class SendError < Error; end

    APPLICATION_NAME = "Job Hunt Agent"

    def initialize(user)
      @user = user
      raise NotConnectedError, "Gmail non connecté" unless @user.gmail_connected?
    end

    def send_email(to:, subject:, body:, attachments: [])
      refresh_token_if_needed!

      message = build_message(to: to, subject: subject, body: body, attachments: attachments)
      response = gmail_service.send_user_message("me", message)

      { external_id: response.id, thread_id: response.thread_id, label_ids: response.label_ids }
    rescue Google::Apis::AuthorizationError => e
      @user.disconnect_gmail!
      raise TokenExpiredError, "Autorisation Gmail expirée: #{e.message}"
    rescue Google::Apis::Error => e
      raise SendError, "Erreur Gmail API: #{e.message}"
    end

    private

    def gmail_service
      @gmail_service ||= begin
        service = Google::Apis::GmailV1::GmailService.new
        service.client_options.application_name = APPLICATION_NAME
        service.authorization = authorization_client
        service
      end
    end

    def authorization_client
      Signet::OAuth2::Client.new(
        client_id: ENV.fetch("GOOGLE_CLIENT_ID"),
        client_secret: ENV.fetch("GOOGLE_CLIENT_SECRET"),
        token_credential_uri: "https://oauth2.googleapis.com/token",
        access_token: @user.google_access_token,
        refresh_token: @user.google_refresh_token,
        expires_at: @user.google_token_expires_at&.to_i
      )
    end

    def refresh_token_if_needed!
      return unless @user.google_token_expired?

      auth = authorization_client
      auth.refresh!

      @user.update!(
        google_access_token: auth.access_token,
        google_token_expires_at: auth.expires_at ? Time.at(auth.expires_at) : nil
      )

      gmail_service.authorization = auth
    rescue Signet::AuthorizationError => e
      @user.disconnect_gmail!
      raise TokenExpiredError, "Le jeton de rafraîchissement Gmail n'est plus valide: #{e.message}"
    end

    def build_message(to:, subject:, body:, attachments: [])
      mail = Mail.new do
        to to
        subject subject
        html_part do
          content_type "text/html; charset=UTF-8"
          body body
        end
      end

      mail.from = @user.email

      attachments.each do |attachment|
        next if attachment[:filename].blank? || attachment[:content].blank?

        mail.attachments[attachment[:filename]] = attachment[:content]
      end

      raw_source = mail.to_s
      Google::Apis::GmailV1::Message.new(raw: Base64.urlsafe_encode64(raw_source))
    end
  end
end
