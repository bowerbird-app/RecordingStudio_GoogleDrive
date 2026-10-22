# frozen_string_literal: true

module RecordingStudioGoogleDrive
  Page = Data.define(:entries, :next_cursor) do
    def more?
      !next_cursor.nil? && !next_cursor.to_s.empty?
    end
  end
end
