# frozen_string_literal: true

module RecordingStudioGoogleDrive
  module Attachable
    class BrowserRow
      def self.from_drive_file(file, open_url: nil)
        if file.respond_to?(:folder?) && file.folder?
          { id: file.id, name: file.name, kind: :folder, open_url: open_url }
        else
          { id: file.id, name: file.name, kind: :file, content_type: file.mime_type }
        end
      end
    end
  end
end
