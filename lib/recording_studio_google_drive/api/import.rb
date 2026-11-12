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
          actor: Access.actor_for(context),
          impersonator: impersonator
        )
      end

      def impersonator
        context.authorized_by
      end

      def finish(result)
        Serialize.import(RecordingStudioAttachable::Api::AttachmentActions::Errors.finish!(result))
      end
    end
  end
end
