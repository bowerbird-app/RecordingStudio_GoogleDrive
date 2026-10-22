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
      return unless hash.respond_to?(:each)

      hash.each do |key, value|
        setter = "#{key}="
        public_send(setter, value) if respond_to?(setter)
      end
    end
  end
end
