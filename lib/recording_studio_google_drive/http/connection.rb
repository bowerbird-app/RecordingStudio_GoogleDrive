# frozen_string_literal: true

module RecordingStudioGoogleDrive
  class Http
    module Connection
      MAX_REDIRECTS = 5
      JSON_HOSTS = %w[www.googleapis.com googleapis.com].freeze
      OPEN_TIMEOUT = 10
      READ_TIMEOUT = 30
      WRITE_TIMEOUT = 30

      private

      def validate_request(uri, follow_cross_host:, redirects_remaining:)
        raise RequestError, "Google Drive request redirected too many times" if redirects_remaining.negative?
        raise RequestError, "Google Drive request must use HTTPS" unless uri.is_a?(URI::HTTPS)
        return if host_allowed?(uri.host, follow_cross_host)

        raise RequestError, "Google Drive request host is not allowed"
      end

      def ssl_start(uri, &)
        Net::HTTP.start(uri.host, uri.port, **ssl_options, &)
      rescue Timeout::Error, SystemCallError, IOError => e
        raise RequestError, "Google Drive request failed (#{e.class})"
      end

      def ssl_options
        {
          use_ssl: true,
          open_timeout: OPEN_TIMEOUT,
          read_timeout: READ_TIMEOUT,
          write_timeout: WRITE_TIMEOUT
        }
      end

      def authorized_get(uri)
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
