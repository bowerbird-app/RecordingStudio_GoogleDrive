# frozen_string_literal: true

require "net/http"
require "timeout"
require "uri"
require "recording_studio_google_drive/http/connection"
require "recording_studio_google_drive/http/limited_get"

module RecordingStudioGoogleDrive
  class Http
    class Transport
      include Connection

      def initialize(access_token:)
        @access_token = access_token
      end

      def get(uri, follow_cross_host:)
        start_request(
          uri,
          authorized_get(uri),
          follow_cross_host: follow_cross_host,
          redirects_remaining: MAX_REDIRECTS
        )
      end

      def get_bytes(uri, follow_cross_host:, max_bytes: nil)
        LimitedGet.new(access_token: access_token).call(
          uri,
          follow_cross_host: follow_cross_host,
          max_bytes: max_bytes
        )
      end

      def post(uri, request, follow_cross_host:)
        start_request(uri, request, follow_cross_host: follow_cross_host, redirects_remaining: MAX_REDIRECTS)
      end

      private

      attr_reader :access_token

      def start_request(uri, request, follow_cross_host:, redirects_remaining:)
        validate_request(uri, follow_cross_host: follow_cross_host, redirects_remaining: redirects_remaining)
        response = ssl_start(uri) { |http| http.request(request) }
        return response unless response.is_a?(Net::HTTPRedirection)
        raise RequestError, "Google Drive request refused a redirect" unless request.method == "GET"

        follow_redirect(uri, response, follow_cross_host: follow_cross_host, redirects_remaining: redirects_remaining)
      end

      def follow_redirect(uri, response, follow_cross_host:, redirects_remaining:)
        location = response["location"].to_s
        return response if location.empty?

        redirected = URI.join(uri.to_s, location)
        refuse_cross_host_json_redirect!(uri, redirected, follow_cross_host)
        start_request(
          redirected,
          authorized_get(redirected),
          follow_cross_host: follow_cross_host,
          redirects_remaining: redirects_remaining - 1
        )
      end
    end
  end
end
