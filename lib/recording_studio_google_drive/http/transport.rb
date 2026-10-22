# frozen_string_literal: true

require "net/http"
require "openssl"
require "socket"
require "timeout"
require "uri"

module RecordingStudioGoogleDrive
  class Http
    class Transport
      MAX_REDIRECTS = 5
      JSON_HOSTS = %w[www.googleapis.com googleapis.com].freeze
      OPEN_TIMEOUT = 10
      READ_TIMEOUT = 30
      WRITE_TIMEOUT = 30
      NETWORK_ERRORS = [
        Timeout::Error,
        SocketError,
        Errno::ECONNRESET,
        EOFError,
        OpenSSL::SSL::SSLError,
        Net::ProtocolError
      ].freeze

      def initialize(access_token:)
        @access_token = access_token
      end

      def get(uri, follow_cross_host:)
        request = Net::HTTP::Get.new(uri)
        request["Authorization"] = bearer if json_host?(uri.host)
        start_request(uri, request, follow_cross_host: follow_cross_host, redirects_remaining: MAX_REDIRECTS)
      end

      def post(uri, request, follow_cross_host:)
        start_request(uri, request, follow_cross_host: follow_cross_host, redirects_remaining: MAX_REDIRECTS)
      end

      private

      attr_reader :access_token

      def start_request(uri, request, follow_cross_host:, redirects_remaining:)
        validate_request(uri, follow_cross_host: follow_cross_host, redirects_remaining: redirects_remaining)
        response = ssl_request(uri, request)
        return response unless response.is_a?(Net::HTTPRedirection)

        follow_redirect(uri, response, follow_cross_host: follow_cross_host, redirects_remaining: redirects_remaining)
      end

      def validate_request(uri, follow_cross_host:, redirects_remaining:)
        raise RequestError, "Google Drive request redirected too many times" if redirects_remaining.negative?
        raise RequestError, "Google Drive request must use HTTPS" unless uri.is_a?(URI::HTTPS)
        return if host_allowed?(uri.host, follow_cross_host)

        raise RequestError, "Google Drive request host is not allowed"
      end

      def ssl_request(uri, request)
        Net::HTTP.start(
          uri.host,
          uri.port,
          use_ssl: true,
          open_timeout: OPEN_TIMEOUT,
          read_timeout: READ_TIMEOUT,
          write_timeout: WRITE_TIMEOUT
        ) { |http| http.request(request) }
      rescue *NETWORK_ERRORS => e
        raise RequestError, "Google Drive request failed (#{e.class})"
      end

      def follow_redirect(uri, response, follow_cross_host:, redirects_remaining:)
        location = response["location"].to_s
        return response if location.empty?

        redirected = URI.join(uri.to_s, location)
        refuse_cross_host_json_redirect!(uri, redirected, follow_cross_host)
        start_request(
          redirected,
          redirect_get(redirected),
          follow_cross_host: follow_cross_host,
          redirects_remaining: redirects_remaining - 1
        )
      end

      def redirect_get(uri)
        request = Net::HTTP::Get.new(uri)
        request["Authorization"] = bearer if json_host?(uri.host)
        request
      end

      def refuse_cross_host_json_redirect!(uri, redirected, follow_cross_host)
        return if follow_cross_host
        return if redirected.host.to_s.downcase == uri.host.to_s.downcase

        raise RequestError, "Google Drive request refused a cross-host redirect"
      end

      def host_allowed?(host, follow_cross_host)
        name = host.to_s.downcase
        return true if json_host?(name)
        return false unless follow_cross_host

        name == "googleusercontent.com" || name.end_with?(".googleusercontent.com")
      end

      def json_host?(host)
        JSON_HOSTS.include?(host.to_s.downcase)
      end

      def bearer
        "Bearer #{access_token}"
      end
    end
  end
end
