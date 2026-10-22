# frozen_string_literal: true

module RecordingStudioGoogleDrive
  class TokenStore
    def initialize(root:, actor:, provider: nil)
      raise ArgumentError, "root is required" if root.nil?
      raise ArgumentError, "actor is required" if actor.nil?

      @root = root
      @actor = actor
      @provider = provider || RecordingStudioGoogleDrive.configuration.oauth_provider_key
    end

    def call
      token
    end

    def access_token
      token
    end

    private

    def token
      connection = RecordingStudioOauth.connection_for(
        provider: @provider,
        root: @root,
        actor: @actor
      )
      raise ReconnectRequired, reconnect_message if connection.nil?

      value = connection.access_token
      raise ReconnectRequired, reconnect_message if value.nil? || value.to_s.strip.empty?

      value
    end

    def reconnect_message
      "Google Drive needs connecting again"
    end
  end
end
