# frozen_string_literal: true

module RecordingStudioGoogleDrive
  class AccessToken
    def initialize(provider)
      callable = provider.respond_to?(:call) || provider.respond_to?(:access_token)
      if provider.instance_of?(String) || !callable
        raise ArgumentError, "token provider must respond to call or access_token"
      end

      @provider = provider
    end

    def to_s
      value = read
      raise ReconnectRequired, "Google Drive access token is missing" if value.nil? || value.to_s.strip.empty?

      value.to_s
    end

    private

    def read
      @provider.respond_to?(:call) ? @provider.call : @provider.access_token
    end
  end
end
