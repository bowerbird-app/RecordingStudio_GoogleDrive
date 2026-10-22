# frozen_string_literal: true

module RecordingStudioGoogleDrive
  class Configuration
    DEFAULT_PAGE_SIZE = 25
    DEFAULT_OAUTH_PROVIDER_KEY = :google_drive
    DEFAULT_AUTHORIZE_URL = "https://accounts.google.com/o/oauth2/v2/auth"
    DEFAULT_TOKEN_URL = "https://oauth2.googleapis.com/token"
    DEFAULT_REVOKE_URL = "https://oauth2.googleapis.com/revoke"
    DEFAULT_SCOPES = ["https://www.googleapis.com/auth/drive"].freeze
    DEFAULT_EXTRA_AUTHORIZE_PARAMS = {
      "access_type" => "offline",
      "prompt" => "consent"
    }.freeze

    attr_accessor :page_size, :oauth_provider_key, :authorize_url, :token_url, :revoke_url,
                  :scopes, :pkce, :refresh, :extra_authorize_params, :client_id, :client_secret, :http
    attr_reader :hooks

    def initialize
      apply_client_defaults
      apply_oauth_defaults
      @hooks = RecordingStudio::Hooks.new
    end

    def oauth_provider_attrs
      oauth_endpoint_attrs.merge(oauth_credential_attrs)
    end

    def to_h
      { page_size: page_size }
    end

    def merge!(hash)
      raise ArgumentError, "Google Drive configuration must be a hash" unless hash.is_a?(Hash)

      hash.each do |key, value|
        setter = "#{key}="
        raise ArgumentError, "unknown Google Drive configuration key: #{key}" unless respond_to?(setter)

        public_send(setter, value)
      end
    end

    private

    def apply_client_defaults
      @page_size = DEFAULT_PAGE_SIZE
      @client_id = nil
      @client_secret = nil
      @http = nil
    end

    def apply_oauth_defaults
      @oauth_provider_key = DEFAULT_OAUTH_PROVIDER_KEY
      @authorize_url = DEFAULT_AUTHORIZE_URL
      @token_url = DEFAULT_TOKEN_URL
      @revoke_url = DEFAULT_REVOKE_URL
      @scopes = DEFAULT_SCOPES.dup
      @pkce = true
      @refresh = true
      @extra_authorize_params = DEFAULT_EXTRA_AUTHORIZE_PARAMS.dup
    end

    def oauth_endpoint_attrs
      {
        key: oauth_provider_key,
        authorize_url: authorize_url,
        token_url: token_url,
        scopes: Array(scopes),
        pkce: pkce,
        refresh: refresh,
        revoke_url: revoke_url,
        extra_authorize_params: extra_authorize_params
      }
    end

    def oauth_credential_attrs
      attrs = {}
      attrs[:client_id] = client_id if present_credential?(client_id)
      attrs[:client_secret] = client_secret if present_credential?(client_secret)
      attrs[:http] = http if http
      attrs
    end

    def present_credential?(value)
      value.respond_to?(:to_s) && value.to_s.strip != ""
    end
  end
end
