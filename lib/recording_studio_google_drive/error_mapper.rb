# frozen_string_literal: true

require "json"

module RecordingStudioGoogleDrive
  module ErrorMapper
    module_function

    RECONNECT_REASONS = %w[authError invalidCredentials].freeze
    RECONNECT_STATUSES = %w[UNAUTHENTICATED ACCESS_TOKEN_SCOPE_INSUFFICIENT].freeze
    RECONNECT_OAUTH_CODES = %w[invalid_token invalid_grant unauthorized_client].freeze

    def from_response(response, raw_body)
      body = parse_object(raw_body)
      klass = reconnect?(response, body) ? ReconnectRequired : RequestError
      klass.new(error_message(response, body, raw_body))
    end

    def reconnect?(response, body)
      code = response.code.to_i
      return true if code == 401
      return true if reconnect_oauth_code?(body)
      return true if reconnect_status?(body)
      return true if reconnect_reason?(body)

      false
    end

    def reconnect_oauth_code?(body)
      RECONNECT_OAUTH_CODES.include?(body["error"].to_s)
    end

    def reconnect_status?(body)
      status = nested_error(body)["status"].to_s
      RECONNECT_STATUSES.include?(status)
    end

    def reconnect_reason?(body)
      reasons = nested_error(body)["errors"]
      return false unless reasons.is_a?(Array)

      reasons.any? { |entry| RECONNECT_REASONS.include?(entry.is_a?(Hash) ? entry["reason"].to_s : "") }
    end

    def nested_error(body)
      error = body["error"]
      error.is_a?(Hash) ? error : {}
    end

    def error_message(response, body, raw_body)
      nested = nested_error(body)
      first_text(nested["message"], body["error_description"]) || fallback_message(response, raw_body)
    end

    def first_text(*values)
      values.map(&:to_s).find { |value| !value.empty? }
    end

    def fallback_message(response, raw_body)
      status = response.code.to_s
      snippet = raw_body.to_s.gsub(/\s+/, " ").strip
      snippet = "#{snippet[0, 197]}..." if snippet.length > 200
      details = snippet.empty? ? "no response body" : snippet

      "Google Drive request failed (HTTP #{status}): #{details}"
    end

    def parse_object(raw)
      return {} if raw.nil? || raw.to_s.empty?

      parsed = JSON.parse(raw)
      parsed.is_a?(Hash) ? parsed : {}
    rescue JSON::ParserError
      {}
    end
  end
end
