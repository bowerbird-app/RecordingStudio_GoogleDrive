# frozen_string_literal: true

module RecordingStudioGoogleDrive
  class Configuration
    DEFAULT_PAGE_SIZE = 25

    attr_accessor :page_size
    attr_reader :hooks

    def initialize
      @page_size = DEFAULT_PAGE_SIZE
      @hooks = RecordingStudio::Hooks.new
    end

    def to_h
      { page_size: page_size }
    end

    def merge!(hash)
      raise ArgumentError, "Google Drive configuration must be a hash" unless hash.is_a?(Hash)

      hash.each do |key, value|
        setter = "#{key}="
        raise ArgumentError, "unknown Google Drive configuration key: #{key}" unless respond_to?(setter)

        public_send(setter, value)
      end
    end
  end
end
