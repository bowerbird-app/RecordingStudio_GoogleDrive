# frozen_string_literal: true

module RecordingStudioGoogleDrive
  class Http
    class ByteCap
      OVERSIZE = "Remote file exceeds maximum file size"

      def self.reject_size!(size, max_bytes)
        new(max_bytes).reject_size!(size)
      end

      def initialize(max_bytes)
        @max_bytes = max_bytes
      end

      def reject_size!(size)
        return if size.nil?

        check!(size)
      end

      def read(response)
        return read_all(response) unless response.is_a?(Net::HTTPSuccess)

        check_length!(response["content-length"])
        body = +"".b
        each_chunk(response) do |chunk|
          check!(body.bytesize + chunk.bytesize)
          body << chunk
        end
        body
      end

      private

      attr_reader :max_bytes

      def read_all(response)
        body = +"".b
        each_chunk(response) { |chunk| body << chunk }
        body
      end

      def check_length!(length)
        return if length.blank?

        check!(length.to_i)
      end

      def check!(bytes)
        return if max_bytes.blank? || bytes <= max_bytes

        raise ArgumentError, OVERSIZE
      end

      def each_chunk(response, &block)
        raise RequestError, "Google Drive download body could not be streamed" unless response.respond_to?(:read_body)

        response.read_body { |chunk| block.call(chunk.to_s.b) }
      end
    end
  end
end
