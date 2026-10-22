# frozen_string_literal: true

require "erb"

module RecordingStudioGoogleDrive
  class Client
    FILE_FIELDS = "id,name,mimeType,resourceKey,webViewLink,size,modifiedTime"

    def initialize(token_provider:, page_size: nil)
      @access_token = AccessToken.new(token_provider)
      @page_size = page_size
      @http = Http.new(access_token: @access_token)
    end

    def list(parent_id: nil, cursor: nil, page_size: nil)
      Listing.page(
        http,
        query: nil,
        parent_id: parent_id,
        cursor: cursor,
        page_size: resolved_page_size(page_size)
      )
    end

    def search(query, cursor: nil, page_size: nil)
      Listing.page(
        http,
        query: query,
        parent_id: nil,
        cursor: cursor,
        page_size: resolved_page_size(page_size)
      )
    end

    def fetch_file(file_id, resource_key: nil)
      raw = http.get_json(
        file_resource_path(file_id),
        fields: FILE_FIELDS,
        resourceKey: resource_key,
        supportsAllDrives: true
      )
      DriveFile.from_api(raw)
    end

    def download(file_id, resource_key: nil)
      metadata = fetch_file(file_id, resource_key: resource_key)
      export = ExportFormats.lookup(metadata.mime_type)
      DownloadedFile.new(
        filename: ExportFormats.filename(metadata.name, export),
        content_type: ExportFormats.content_type(metadata.mime_type, export),
        body: download_body(file_id, resource_key, export)
      )
    end

    def upload_file(io:, filename:, content_type:, parent_id: nil)
      metadata = { name: filename, mimeType: content_type }
      metadata[:parents] = [parent_id] if parent_id
      raw = http.post_multipart(
        "/files",
        params: { supportsAllDrives: true, fields: FILE_FIELDS },
        metadata: metadata,
        body: read_io(io),
        content_type: content_type
      )
      DriveFile.from_api(raw)
    end

    private

    attr_reader :http

    def resolved_page_size(page_size)
      page_size || @page_size || RecordingStudioGoogleDrive.configuration.page_size
    end

    def download_body(file_id, resource_key, export)
      path = file_resource_path(file_id)
      return http.get_bytes("#{path}/export", export_params(resource_key, export)) if export

      http.get_bytes(path, media_params(resource_key))
    end

    def export_params(resource_key, export)
      { mimeType: export.fetch(:content_type), resourceKey: resource_key, supportsAllDrives: true }
    end

    def media_params(resource_key)
      { alt: "media", resourceKey: resource_key, supportsAllDrives: true }
    end

    def file_resource_path(file_id)
      "/files/#{ERB::Util.url_encode(file_id.to_s)}"
    end

    def read_io(io)
      return io if io.instance_of?(String)
      return io.read if io.respond_to?(:read)

      io.to_s
    end
  end
end
