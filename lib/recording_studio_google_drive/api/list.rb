# frozen_string_literal: true

module RecordingStudioGoogleDrive
  module Api
    class List
      def self.call(context)
        new(context).call
      end

      def initialize(context)
        @context = context
      end

      def call
        Serialize.page(listed_page)
      rescue RecordingStudioGoogleDrive::Error => e
        Access.raise_drive_error!(e)
      end

      private

      attr_reader :context

      def listed_page
        Access.client_for(Access.authorize!(context), context).list(**list_kwargs)
      end

      def list_kwargs
        context.params.slice(:parent_id, :cursor, :page_size)
      end
    end
  end
end
