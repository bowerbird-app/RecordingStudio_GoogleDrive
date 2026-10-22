# frozen_string_literal: true

require "recording_studio"
require "recording_studio_google_drive/version"
require "recording_studio_google_drive/errors"
require "recording_studio_google_drive/access_token"
require "recording_studio_google_drive/drive_file"
require "recording_studio_google_drive/error_mapper"
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
  end
end
