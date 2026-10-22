# frozen_string_literal: true

module RecordingStudioGoogleDrive
  module ExportFormats
    MIME_TYPES = {
      "application/vnd.google-apps.document" => { content_type: "application/pdf", extension: ".pdf" },
      "application/vnd.google-apps.drawing" => { content_type: "image/png", extension: ".png" },
      "application/vnd.google-apps.presentation" => { content_type: "application/pdf", extension: ".pdf" },
      "application/vnd.google-apps.spreadsheet" => { content_type: "text/csv", extension: ".csv" }
    }.freeze

    module_function

    def lookup(mime_type)
      MIME_TYPES[mime_type]
    end

    def filename(name, export)
      return name unless export

      extension = export.fetch(:extension)
      name.end_with?(extension) ? name : "#{name}#{extension}"
    end

    def content_type(mime_type, export)
      export ? export.fetch(:content_type) : mime_type
    end
  end
end
