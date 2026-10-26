# frozen_string_literal: true

require "recording_studio"
require "recording_studio_oauth"
require "recording_studio_google_drive/version"
require "recording_studio_google_drive/errors"
require "recording_studio_google_drive/access_token"
require "recording_studio_google_drive/token_store"
require "recording_studio_google_drive/drive_file"
require "recording_studio_google_drive/page"
require "recording_studio_google_drive/downloaded_file"
require "recording_studio_google_drive/drive_query"
require "recording_studio_google_drive/listing"
require "recording_studio_google_drive/export_formats"
require "recording_studio_google_drive/error_mapper"
require "recording_studio_google_drive/http/connection"
require "recording_studio_google_drive/http/byte_cap"
require "recording_studio_google_drive/http/transport"
require "recording_studio_google_drive/http/multipart"
require "recording_studio_google_drive/http"
require "recording_studio_google_drive/client"
require "recording_studio_google_drive/configuration"
require "recording_studio_google_drive/engine"

module RecordingStudioGoogleDrive
  MINIMUM_ATTACHABLE_VERSION = "0.21.0"

  class << self
    def configuration
      @configuration ||= Configuration.new
    end

    def configure
      yield(configuration) if block_given?
      configuration
    end

    def register_oauth_provider(**overrides)
      return if oauth_credentials_blank?(overrides)

      RecordingStudioOauth.register_outbound_provider(
        **oauth_provider_attrs,
        **overrides,
        kind: :root
      )
    end
    alias register_oauth_provider! register_oauth_provider

    def oauth_provider_attrs
      configuration.oauth_provider_attrs
    end

    def load_attachable_engine!
      assert_attachable_version!(RecordingStudioAttachable::VERSION)
      require "recording_studio_google_drive/attachable"
    end

    def load_attachable_addon!
      load_attachable_engine!
      Attachable.register_adapter_routes!
      Attachable.register_upload_provider!
    end

    def picker_access_token(root:, actor:)
      TokenStore.new(root: root, actor: actor).access_token
    end

    def assert_attachable_version!(version)
      required = Gem::Version.new(MINIMUM_ATTACHABLE_VERSION)
      return if Gem::Version.new(version) >= required

      raise "recording_studio_google_drive requires recording_studio_attachable >= #{required} " \
            "(got #{Gem::Version.new(version)})"
    end

    private

    def oauth_credentials_blank?(overrides = {})
      client_id, client_secret = resolved_oauth_credentials(overrides)
      client_id.blank? && client_secret.blank?
    end

    def resolved_oauth_credentials(overrides = {})
      stored = stored_oauth_credentials
      [
        strip_oauth_credential(overrides[:client_id]) ||
          strip_oauth_credential(configuration.client_id) || stored[:client_id],
        strip_oauth_credential(overrides[:client_secret]) ||
          strip_oauth_credential(configuration.client_secret) || stored[:client_secret]
      ]
    end

    def stored_oauth_credentials
      raw = rails_oauth_outbound_credentials
      return { client_id: nil, client_secret: nil } if raw.blank?

      {
        client_id: strip_oauth_credential(raw[:client_id] || raw["client_id"]),
        client_secret: strip_oauth_credential(raw[:client_secret] || raw["client_secret"])
      }
    end

    def rails_oauth_outbound_credentials
      return unless defined?(Rails) && Rails.application.respond_to?(:credentials)

      key = configuration.oauth_provider_key
      creds = Rails.application.credentials
      creds.dig(:recording_studio_oauth, :outbound, key.to_sym).presence ||
        creds.dig(:recording_studio_oauth, :outbound, key.to_s)
    end

    def strip_oauth_credential(value)
      stripped = value.respond_to?(:to_s) ? value.to_s.strip : ""
      stripped.empty? ? nil : stripped
    end
  end
end

ActiveSupport.on_load(:recording_studio_attachable) do
  RecordingStudioGoogleDrive.load_attachable_engine!
end
