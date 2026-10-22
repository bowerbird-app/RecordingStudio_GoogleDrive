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
require "recording_studio_google_drive/http/transport"
require "recording_studio_google_drive/http/multipart"
require "recording_studio_google_drive/http"
require "recording_studio_google_drive/client"
require "recording_studio_google_drive/configuration"
require "recording_studio_google_drive/engine"

module RecordingStudioGoogleDrive
  class << self
    def configuration
      @configuration ||= Configuration.new
    end

    def configure
      yield(configuration) if block_given?
      configuration
    end

    def register_oauth_provider!
      RecordingStudioOauth.register_outbound_provider(**oauth_provider_attrs)
    end

    def oauth_provider_attrs
      configuration.oauth_provider_attrs
    end
  end
end
