# frozen_string_literal: true

module RecordingStudioGoogleDrive
  module Api
    module Serialize
      module_function

      def page(page)
        {
          entries: Array(page.entries).map(&:to_h),
          next_cursor: page.next_cursor
        }
      end

      def import(recordings)
        { attachments: Array(recordings).map { |recording| imported_as_json(recording) } }
      end

      def imported_as_json(recording)
        attachment = recording.recordable
        {
          id: recording.id,
          name: attachment.respond_to?(:name) ? attachment.name : nil,
          kind: attachment.respond_to?(:attachment_kind) ? attachment.attachment_kind : nil
        }
      end
    end
  end
end
