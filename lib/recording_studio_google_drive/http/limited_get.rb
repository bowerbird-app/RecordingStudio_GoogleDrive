# frozen_string_literal: true

require "net/http"
require "timeout"
require "uri"
require "recording_studio_google_drive/http/byte_cap"
require "recording_studio_google_drive/http/connection"

module RecordingStudioGoogleDrive
  class Http
    class LimitedGet
      include Connection

      def initialize(access_token:)
        @access_token = access_token
      end

      def call(uri, follow_cross_host:, max_bytes:)
        start(
          uri,
          authorized_get(uri),
          follow_cross_host: follow_cross_host,
          redirects_remaining: MAX_REDIRECTS,
          max_bytes: max_bytes
        )
      end

      private

      attr_reader :access_token

      def start(uri, request, follow_cross_host:, redirects_remaining:, max_bytes:)
        validate_request(uri, follow_cross_host: follow_cross_host, redirects_remaining: redirects_remaining)
        read_response(uri, request, follow_cross_host:, redirects_remaining:, max_bytes:)
      end

      def read_response(uri, request, follow_cross_host:, redirects_remaining:, max_bytes:)
        ssl_start(uri) do |http|
          http.request(request) do |response|
            return result_for(uri, response, follow_cross_host:, redirects_remaining:, max_bytes:)
          end
        end
      end

      def result_for(uri, response, follow_cross_host:, redirects_remaining:, max_bytes:)
        if response.is_a?(Net::HTTPRedirection)
          return follow(uri, response, follow_cross_host:, redirects_remaining:, max_bytes:)
        end

        [response, ByteCap.new(max_bytes).read(response)]
      end

      def follow(uri, response, follow_cross_host:, redirects_remaining:, max_bytes:)
        location = response["location"].to_s
        return capped(response, max_bytes) if location.empty?

        continue_redirect(uri, location, follow_cross_host:, redirects_remaining:, max_bytes:)
      end

      def continue_redirect(uri, location, follow_cross_host:, redirects_remaining:, max_bytes:)
        redirected = URI.join(uri.to_s, location)
        refuse_cross_host_json_redirect!(uri, redirected, follow_cross_host)
        start(
          redirected,
          authorized_get(redirected),
          follow_cross_host: follow_cross_host,
          redirects_remaining: redirects_remaining - 1,
          max_bytes: max_bytes
        )
      end

      def capped(response, max_bytes)
        [response, ByteCap.new(max_bytes).read(response)]
      end
    end
  end
end
