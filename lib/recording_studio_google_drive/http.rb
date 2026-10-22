# frozen_string_literal: true

require "json"
require "net/http"
require "securerandom"
require "uri"

module RecordingStudioGoogleDrive
  class Http
    API_ROOT = "https://www.googleapis.com/drive/v3"
    UPLOAD_ROOT = "https://www.googleapis.com/upload/drive/v3"
    MAX_REDIRECTS = 5
    JSON_HOSTS = %w[www.googleapis.com googleapis.com].freeze

    def initialize(access_token:)
      @access_token = access_token
    end

    def get_json(path, params = {})
      response = perform(uri_for(API_ROOT, path, params), follow_cross_host: false)
      raise_unless_success(response)
      parse_json_object(response.body)
    end

    def get_bytes(path, params = {})
      response = perform(uri_for(API_ROOT, path, params), follow_cross_host: true)
      raise_unless_success(response)
      response.body
    end

    def post_multipart(path, params:, metadata:, body:, content_type:)
      boundary = "rs_google_drive_#{SecureRandom.hex(16)}"
      uri = uri_for(UPLOAD_ROOT, path, params.merge(uploadType: "multipart"))
      request = Net::HTTP::Post.new(uri)
      request["Authorization"] = bearer
      request["Content-Type"] = "multipart/related; boundary=#{boundary}"
      request.body = multipart_body(boundary, metadata, body, content_type)
      response = start_request(uri, request, follow_cross_host: false, redirects_remaining: MAX_REDIRECTS)
      raise_unless_success(response)
      parse_json_object(response.body)
    end

    private

    attr_reader :access_token

    def perform(uri, follow_cross_host:)
      request = Net::HTTP::Get.new(uri)
      request["Authorization"] = bearer if json_host?(uri.host)
      start_request(uri, request, follow_cross_host: follow_cross_host, redirects_remaining: MAX_REDIRECTS)
    end

    def start_request(uri, request, follow_cross_host:, redirects_remaining:)
      raise RequestError, "Google Drive request redirected too many times" if redirects_remaining.negative?
      raise RequestError, "Google Drive request must use HTTPS" unless uri.is_a?(URI::HTTPS)
      raise RequestError, "Google Drive request host is not allowed" unless host_allowed?(uri.host, follow_cross_host)

      Net::HTTP.start(uri.host, uri.port, use_ssl: true) do |http|
        response = http.request(request)
        return response unless response.is_a?(Net::HTTPRedirection)

        follow_redirect(uri, response, follow_cross_host: follow_cross_host, redirects_remaining: redirects_remaining)
      end
    end

    def follow_redirect(uri, response, follow_cross_host:, redirects_remaining:)
      location = response["location"].to_s
      return response if location.empty?

      redirected = URI.join(uri.to_s, location)
      refuse_cross_host_json_redirect!(uri, redirected, follow_cross_host)
      next_request = Net::HTTP::Get.new(redirected)
      next_request["Authorization"] = bearer if json_host?(redirected.host)
      start_request(
        redirected,
        next_request,
        follow_cross_host: follow_cross_host,
        redirects_remaining: redirects_remaining - 1
      )
    end

    def refuse_cross_host_json_redirect!(uri, redirected, follow_cross_host)
      return if follow_cross_host
      return if redirected.host.to_s.downcase == uri.host.to_s.downcase

      raise RequestError, "Google Drive request refused a cross-host redirect"
    end

    def uri_for(root, path, params)
      uri = URI.join("#{root}/", path.to_s.sub(%r{\A/+}, ""))
      compact_params = params.compact
      uri.query = URI.encode_www_form(compact_params) if compact_params.any?
      uri
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

    def raise_unless_success(response)
      return if response.is_a?(Net::HTTPSuccess)

      raise ErrorMapper.from_response(response, response.body)
    end

    def parse_json_object(raw)
      parsed = JSON.parse(raw.to_s)
      return parsed if parsed.is_a?(Hash)

      raise RequestError, "Google Drive returned a non-object JSON body"
    rescue JSON::ParserError
      raise RequestError, "Google Drive returned invalid JSON"
    end

    def multipart_body(boundary, metadata, body, content_type)
      [
        "--#{boundary}\r\n",
        "Content-Type: application/json; charset=UTF-8\r\n\r\n",
        "#{JSON.generate(metadata)}\r\n",
        "--#{boundary}\r\n",
        "Content-Type: #{content_type}\r\n\r\n",
        body.to_s,
        "\r\n--#{boundary}--\r\n"
      ].join
    end
  end
end
