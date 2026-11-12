# frozen_string_literal: true

module RecordingStudioGoogleDrive
  module Api
    module Serialize
      module_function

      def page(page)
        {
          entries: Array(page.entries).map(&:to_h),
          next_cursor: page.next_cursor,
          more: page.more?
        }
      end

      def import(recordings)
        { attachments: Array(recordings).map { |recording| { id: recording.id } } }
      end
    end
  end
end
