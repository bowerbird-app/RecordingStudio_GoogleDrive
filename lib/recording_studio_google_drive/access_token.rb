# frozen_string_literal: true

module RecordingStudioGoogleDrive
  class AccessToken
    def initialize(provider)
      @provider = provider
    end

    def to_s
      value = read
      raise ArgumentError, "token provider returned a blank access token" if value.to_s.strip.empty?

      value.to_s
    end

    private

    def read
      if @provider.respond_to?(:call)
        @provider.call
      elsif @provider.respond_to?(:access_token)
        @provider.access_token
      else
        raise ArgumentError, "token provider must respond to call or access_token"
      end
    end
  end
end
