# frozen_string_literal: true

require "test_helper"
require "net/http"

class HttpByteCapTest < Minitest::Test
  def test_multi_chunk_body_stops_before_appending_past_max_bytes
    appended = []
    first = "x" * 8
    second = "y" * 8
    second_chunk = Object.new
    second_chunk.define_singleton_method(:to_s) { second_chunk }
    second_chunk.define_singleton_method(:b) { second_chunk }
    second_chunk.define_singleton_method(:bytesize) { second.bytesize }
    second_chunk.define_singleton_method(:to_str) do
      appended << second
      second
    end

    response = Object.new
    response.define_singleton_method(:is_a?) { |klass| klass == Net::HTTPSuccess }
    response.define_singleton_method(:[]) { |_header| nil }
    response.define_singleton_method(:read_body) do |&block|
      block.call(first)
      block.call(second_chunk)
    end

    error = assert_raises(ArgumentError) do
      RecordingStudioGoogleDrive::Http::ByteCap.new(12).read(response)
    end

    assert_equal RecordingStudioGoogleDrive::Http::ByteCap::OVERSIZE, error.message
    assert_empty appended
  end
end
