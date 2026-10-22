# frozen_string_literal: true

module RecordingStudioGoogleDrive
  class Http
    module Multipart
      module_function

      def body(boundary:, metadata:, body:, content_type:)
        [
          "--#{boundary}\r\n".b,
          "Content-Type: application/json; charset=UTF-8\r\n\r\n".b,
          "#{JSON.generate(metadata)}\r\n".b,
          "--#{boundary}\r\n".b,
          "Content-Type: #{sanitise_content_type(content_type)}\r\n\r\n".b,
          body.to_s.b,
          "\r\n--#{boundary}--\r\n".b
        ].join
      end

      def sanitise_content_type(content_type)
        cleaned = content_type.to_s.gsub(/[\r\n]/, "").strip
        cleaned.empty? ? "application/octet-stream" : cleaned
      end
    end
  end
end
