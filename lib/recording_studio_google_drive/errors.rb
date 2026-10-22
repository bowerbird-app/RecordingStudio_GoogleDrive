# frozen_string_literal: true

module RecordingStudioGoogleDrive
  class Error < StandardError; end

  class ReconnectRequired < Error; end

  class RequestError < Error; end
end
