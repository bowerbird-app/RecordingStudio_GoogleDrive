# frozen_string_literal: true

module RecordingStudioGoogleDrive
  class Error < StandardError; end

  class ReconnectRequired < Error; end

  class RequestError < Error
    attr_reader :status, :code

    def initialize(message = nil, status: nil, code: nil)
      @status = status
      @code = code
      super(message)
    end
  end
end
