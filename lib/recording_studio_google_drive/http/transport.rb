# frozen_string_literal: true

require "net/http"
require "timeout"
require "uri"
require "recording_studio_google_drive/http/byte_cap"
require "recording_studio_google_drive/http/connection"

module RecordingStudioGoogleDrive
  class Http
    class Transport
      include Connection

      def initialize(access_token:)
        @access_token = access_token
      end

      def get(uri, follow_cross_host:)
        perform(uri, authorized_get(uri), follow_cross_host: follow_cross_host)
      end

      def get_bytes(uri, follow_cross_host:, max_bytes: nil)
        perform(uri, authorized_get(uri), follow_cross_host: follow_cross_host) do |response|
          ByteCap.new(max_bytes).read(response)
        end
      end

      def post(uri, request, follow_cross_host:)
        perform(uri, request, follow_cross_host: follow_cross_host)
      end

      private

      attr_reader :access_token

      def perform(uri, request, follow_cross_host:, redirects_remaining: MAX_REDIRECTS, &read_body)
        validate_request(uri, follow_cross_host: follow_cross_host, redirects_remaining: redirects_remaining)
        ssl_start(uri) do |http|
          http.request(request) do |response|
            return complete(uri, request, response, follow_cross_host:, redirects_remaining:, &read_body)
          end
        end
      end

      def complete(uri, request, response, follow_cross_host:, redirects_remaining:, &read_body)
        if response.is_a?(Net::HTTPRedirection)
          return follow_redirect(uri, request, response, follow_cross_host:, redirects_remaining:, &read_body)
        end

        finish(response, &read_body)
      end

      def follow_redirect(uri, request, response, follow_cross_host:, redirects_remaining:, &read_body)
        location = response["location"].to_s
        return finish(response, &read_body) if location.empty?
        raise RequestError, "Google Drive request refused a redirect" unless request.method == "GET"

        continue_redirect(uri, location, follow_cross_host:, redirects_remaining:, &read_body)
      end

      def continue_redirect(uri, location, follow_cross_host:, redirects_remaining:, &read_body)
        redirected = URI.join(uri.to_s, location)
        refuse_cross_host_json_redirect!(uri, redirected, follow_cross_host)
        perform(
          redirected,
          authorized_get(redirected),
          follow_cross_host: follow_cross_host,
          redirects_remaining: redirects_remaining - 1,
          &read_body
        )
      end

      def finish(response, &read_body)
        return [response, read_body.call(response)] if read_body

        response.body
        response
      end
    end
  end
end
