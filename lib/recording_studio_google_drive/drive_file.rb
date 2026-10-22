# frozen_string_literal: true

module RecordingStudioGoogleDrive
  FOLDER_MIME_TYPE = "application/vnd.google-apps.folder"

  DriveFile = Data.define(:id, :name, :mime_type, :size, :modified_at, :web_view_link, :resource_key) do
    def self.from_api(row)
      new(
        id: row.fetch("id"),
        name: row.fetch("name"),
        mime_type: row.fetch("mimeType"),
        size: integer_or_nil(row["size"]),
        modified_at: row["modifiedTime"],
        web_view_link: row["webViewLink"],
        resource_key: row["resourceKey"]
      )
    end

    def folder?
      mime_type == FOLDER_MIME_TYPE
    end

    def self.integer_or_nil(value)
      return if value.nil? || value.to_s.empty?

      value.to_i
    end
    private_class_method :integer_or_nil
  end

  FilePage = Data.define(:files, :next_page_token)

  DownloadedFile = Data.define(:id, :filename, :content_type, :body, :byte_size)
end
