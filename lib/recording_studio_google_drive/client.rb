# frozen_string_literal: true

require "erb"

module RecordingStudioGoogleDrive
  class Client
    EXPORT_MIME_TYPES = {
      "application/vnd.google-apps.document" => { content_type: "application/pdf", extension: ".pdf" },
      "application/vnd.google-apps.drawing" => { content_type: "image/png", extension: ".png" },
      "application/vnd.google-apps.presentation" => { content_type: "application/pdf", extension: ".pdf" },
      "application/vnd.google-apps.spreadsheet" => { content_type: "text/csv", extension: ".csv" }
    }.freeze

    LIST_FIELDS = "nextPageToken,files(id,name,mimeType,size,modifiedTime,webViewLink,resourceKey)"
    FILE_FIELDS = "id,name,mimeType,resourceKey,webViewLink,size,modifiedTime"

    def initialize(token_provider:, page_size: nil)
      @access_token = AccessToken.new(token_provider)
      @page_size = page_size
      @http = Http.new(access_token: @access_token)
    end

    def list_files(query: nil, page_token: nil, page_size: nil, parent_id: nil)
      raw = http.get_json(
        "/files",
        fields: LIST_FIELDS,
        includeItemsFromAllDrives: true,
        pageSize: resolved_page_size(page_size),
        pageToken: page_token,
        q: drive_query(query, parent_id),
        supportsAllDrives: true
      )
      FilePage.new(
        files: Array(raw["files"]).map { |row| DriveFile.from_api(row) },
        next_page_token: raw["nextPageToken"]
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

    def download_file(file_id, resource_key: nil)
      metadata = fetch_file(file_id, resource_key: resource_key)
      export = EXPORT_MIME_TYPES[metadata.mime_type]
      body = download_body(file_id, resource_key, export)
      DownloadedFile.new(
        id: metadata.id,
        filename: download_filename(metadata.name, export),
        content_type: download_content_type(metadata.mime_type, export),
        body: body,
        byte_size: body.bytesize
      )
    end

    def upload_file(io:, filename:, content_type:, parent_id: nil)
      metadata = { name: filename, mimeType: content_type }
      metadata[:parents] = [parent_id] if parent_id
      raw = http.post_multipart(
        "/files",
        params: { supportsAllDrives: true, fields: "id,name,mimeType,webViewLink,size,modifiedTime,resourceKey" },
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
      if export
        http.get_bytes(
          "#{file_resource_path(file_id)}/export",
          mimeType: export.fetch(:content_type),
          resourceKey: resource_key,
          supportsAllDrives: true
        )
      else
        http.get_bytes(
          file_resource_path(file_id),
          alt: "media",
          resourceKey: resource_key,
          supportsAllDrives: true
        )
      end
    end

    def download_filename(name, export)
      export ? append_extension(name, export.fetch(:extension)) : name
    end

    def download_content_type(mime_type, export)
      export ? export.fetch(:content_type) : mime_type
    end

    def drive_query(query, parent_id)
      clauses = ["trashed = false"]
      clauses << "'#{escape_drive_string(parent_id)}' in parents" if present?(parent_id)
      clauses << "name contains '#{escape_drive_string(query)}'" if present?(query)
      clauses.join(" and ")
    end

    def escape_drive_string(value)
      value.to_s.gsub("'", "\\\\'")
    end

    def present?(value)
      !value.nil? && !value.to_s.empty?
    end

    def append_extension(filename, extension)
      filename.end_with?(extension) ? filename : "#{filename}#{extension}"
    end

    def file_resource_path(file_id)
      "/files/#{ERB::Util.url_encode(file_id.to_s)}"
    end

    def read_io(io)
      return io if io.is_a?(String)
      return io.read if io.respond_to?(:read)

      io.to_s
    end
  end
end
