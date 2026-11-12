# frozen_string_literal: true

require_relative "api/access"
require_relative "api/contracts"
require_relative "api/serialize"
require_relative "api/list"
require_relative "api/search"
require_relative "api/import"
require_relative "api/registration"

module RecordingStudioGoogleDrive
  module Api
    module_function

    def register!
      return unless recording_studio_api_available?
      return unless attachable_available?

      Registration.register!
      true
    end

    def recording_studio_api_available?
      defined?(RecordingStudioApi) && RecordingStudioApi.respond_to?(:register_endpoint)
    end

    def attachable_available?
      defined?(RecordingStudioAttachable)
    end
  end
end
