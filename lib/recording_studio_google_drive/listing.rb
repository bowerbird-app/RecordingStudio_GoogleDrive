# frozen_string_literal: true

module RecordingStudioGoogleDrive
  module Listing
    FIELDS = "nextPageToken,files(id,name,mimeType,size,modifiedTime,webViewLink,resourceKey)"

    module_function

    def page(http, query:, parent_id:, cursor:, page_size:)
      from_api(http.get_json("/files", list_params(query, parent_id, cursor, page_size)))
    end

    def list_params(query, parent_id, cursor, page_size)
      {
        fields: FIELDS,
        includeItemsFromAllDrives: true,
        pageSize: page_size,
        pageToken: cursor,
        q: DriveQuery.build(query: query, parent_id: parent_id),
        supportsAllDrives: true
      }
    end

    def from_api(raw)
      next_cursor = raw["nextPageToken"]
      Page.new(
        entries: Array(raw["files"]).map { |row| DriveFile.from_api(row) },
        next_cursor: next_cursor.nil? || next_cursor.to_s.empty? ? nil : next_cursor
      )
    end
  end
end
