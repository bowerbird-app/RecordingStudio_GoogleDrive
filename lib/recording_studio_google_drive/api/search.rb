# frozen_string_literal: true

module RecordingStudioGoogleDrive
  module Api
    class Search
      def self.call(context)
        new(context).call
      end

      def initialize(context)
        @context = context
      end

      def call
        Serialize.page(searched_page)
      rescue RecordingStudioGoogleDrive::Error => e
        Access.raise_drive_error!(e)
      end

      private

      attr_reader :context

      def searched_page
        Access.client_for(Access.authorize!(context), context).search(**search_kwargs)
      end

      def search_kwargs
        context.params.slice(:query, :parent_id, :cursor, :page_size)
      end
    end
  end
end
