# frozen_string_literal: true

require "erb"
require "recording_studio_google_drive/token_store"

module RecordingStudioGoogleDrive
  class Client
    FILE_FIELDS = "id,name,mimeType,resourceKey,webViewLink,size,modifiedTime"

    def self.for(root:, actor:, page_size: nil)
      new(token_provider: TokenStore.new(root: root, actor: actor), page_size: page_size)
    end

    def initialize(token_provider: nil, root: nil, actor: nil, page_size: nil)
      @access_token = AccessToken.new(resolve_token_provider(token_provider, root, actor))
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

    def search(query:, cursor: nil, page_size: nil, parent_id: nil)
      Listing.page(
        http,
        query: query,
        parent_id: parent_id,
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

    def download(file_id, resource_key: nil, max_bytes: nil)
      metadata = fetch_file(file_id, resource_key: resource_key)
      reject_oversized!(metadata, max_bytes)
      export = ExportFormats.lookup(metadata.mime_type)
      DownloadedFile.new(
        filename: ExportFormats.filename(metadata.name, export),
        content_type: ExportFormats.content_type(metadata.mime_type, export),
        body: download_body(file_id, resource_key, export, max_bytes)
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

    def resolve_token_provider(token_provider, root, actor)
      return token_provider unless token_provider.nil?
      return TokenStore.new(root: root, actor: actor) if root && actor

      raise ArgumentError, "token_provider or root and actor are required"
    end

    def resolved_page_size(page_size)
      page_size || @page_size || RecordingStudioGoogleDrive.configuration.page_size
    end

    def download_body(file_id, resource_key, export, max_bytes)
      path = file_resource_path(file_id)
      return http.get_bytes("#{path}/export", export_params(resource_key, export), max_bytes: max_bytes) if export

      http.get_bytes(path, media_params(resource_key), max_bytes: max_bytes)
    end

    def reject_oversized!(metadata, max_bytes)
      Http::ByteCap.reject_size!(metadata.size, max_bytes)
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

      raise ArgumentError, "upload io must be a String or respond to read"
    end
  end
end
