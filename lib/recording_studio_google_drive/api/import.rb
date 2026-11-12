# frozen_string_literal: true

module RecordingStudioGoogleDrive
  module Api
    class Import
      def self.call(context)
        new(context).call
      end

      def initialize(context)
        @context = context
      end

      def call
        finish(import_result)
      rescue ArgumentError => e
        raise RecordingStudioApi::InvalidActionInputError, e.message
      rescue RecordingStudioGoogleDrive::Error => e
        Access.raise_drive_error!(e)
      end

      private

      attr_reader :context

      def import_result
        recording = Access.authorize!(context)
        Attachable::RemoteImport.call(
          parent_recording: recording,
          attachments: context.params[:attachments],
          actor: Access.actor_for(context)
        )
      end

      def finish(result)
        return Serialize.import(result.value) if result.success?

        finish_failure!(result)
      end

      def finish_failure!(result)
        message = result.error.to_s
        raise RecordingStudioApi::AuthorizationError, message if message.start_with?("Not authorized")

        details = result.respond_to?(:errors) ? Array(result.errors) : []
        raise RecordingStudioApi::InvalidActionInputError.new(message, details: details)
      end
    end
  end
end
