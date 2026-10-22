# frozen_string_literal: true

require "json"
require "net/http"
require "securerandom"
require "uri"

module RecordingStudioGoogleDrive
  class Http
    API_ROOT = "https://www.googleapis.com/drive/v3"
    UPLOAD_ROOT = "https://www.googleapis.com/upload/drive/v3"

    def initialize(access_token:)
      @access_token = access_token
      @transport = Transport.new(access_token: access_token)
    end

    def get_json(path, params = {})
      response = @transport.get(uri_for(API_ROOT, path, params), follow_cross_host: false)
      raise_unless_success(response)
      parse_json_object(response.body)
    end

    def get_bytes(path, params = {})
      response = @transport.get(uri_for(API_ROOT, path, params), follow_cross_host: true)
      raise_unless_success(response)
      response.body
    end

    def post_multipart(path, params:, metadata:, body:, content_type:)
      boundary = "rs_google_drive_#{SecureRandom.hex(16)}"
      uri = uri_for(UPLOAD_ROOT, path, params.merge(uploadType: "multipart"))
      response = @transport.post(
        uri,
        upload_request(uri, boundary, metadata, body, content_type),
        follow_cross_host: false
      )
      raise_unless_success(response)
      parse_json_object(response.body)
    end

    private

    def upload_request(uri, boundary, metadata, body, content_type)
      request = Net::HTTP::Post.new(uri)
      request["Authorization"] = "Bearer #{@access_token}"
      request["Content-Type"] = "multipart/related; boundary=#{boundary}"
      request.body = Multipart.body(
        boundary: boundary,
        metadata: metadata,
        body: body,
        content_type: content_type
      )
      request
    end

    def uri_for(root, path, params)
      uri = URI.join("#{root}/", path.to_s.sub(%r{\A/+}, ""))
      compact_params = params.compact
      uri.query = URI.encode_www_form(compact_params) if compact_params.any?
      uri
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
  end
end
