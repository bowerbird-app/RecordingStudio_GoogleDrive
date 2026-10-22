# frozen_string_literal: true

require "json"

module RecordingStudioGoogleDrive
  module ErrorMapper
    module_function

    RECONNECT_REASONS = %w[authError invalidCredentials].freeze
    RECONNECT_STATUSES = %w[UNAUTHENTICATED ACCESS_TOKEN_SCOPE_INSUFFICIENT].freeze
    RECONNECT_OAUTH_CODES = %w[invalid_token invalid_grant].freeze

    def from_response(response, raw_body)
      body = parse_object(raw_body)
      status = response.code.to_i
      code = structured_error_code(body)
      message = error_message(status, code)
      return ReconnectRequired.new(message) if reconnect?(response, body)

      RequestError.new(message, status: status, code: code)
    end

    def reconnect?(response, body)
      return true if response.code.to_i == 401
      return true if reconnect_oauth_code?(body)
      return true if reconnect_status?(body)
      return true if reconnect_reason?(body)

      false
    end

    def reconnect_oauth_code?(body)
      RECONNECT_OAUTH_CODES.include?(body["error"].to_s)
    end

    def reconnect_status?(body)
      RECONNECT_STATUSES.include?(nested_error(body)["status"].to_s)
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

    def structured_error_code(body)
      error = body["error"]
      return error if error.is_a?(String) && !error.empty?

      nested = nested_error(body)
      first_text(nested["status"])
    end

    def error_message(status, code)
      return "Google Drive request failed (HTTP #{status}): #{code}" if present?(code)

      "Google Drive request failed (HTTP #{status})"
    end

    def first_text(*values)
      values.map(&:to_s).find { |value| !value.empty? }
    end

    def present?(value)
      !value.nil? && !value.to_s.empty?
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
