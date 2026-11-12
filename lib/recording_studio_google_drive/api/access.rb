# frozen_string_literal: true

module RecordingStudioGoogleDrive
  module Api
    module Access
      DENIED_MESSAGE = "API access grant is not authorized for this capability"

      module_function

      def allowed?(context)
        recording = recording_for(context)
        return false if recording.blank? || actor_for(context).blank?

        RecordingStudioAttachable::Authorization.allowed?(
          action: :upload,
          actor: actor_for(context),
          recording: recording
        )
      end

      def authorize!(context)
        recording = recording_for(context)
        raise RecordingStudioApi::NotFoundError, "Recording was not found" if recording.blank?

        role = RecordingStudioAttachable.configuration.auth_role_for(:upload)
        context.access_grant.authorize!(recording: recording, role: role)
        deny! unless allowed?(context)
        recording
      end

      def actor_for(context)
        context&.access_grant&.actor
      end

      def client_for(recording, context)
        Attachable::Integration.client(root: Attachable::Integration.root_for(recording), actor: actor_for(context))
      end

      def raise_drive_error!(error)
        case error
        when ReconnectRequired
          raise RecordingStudioApi::AuthenticationError, error.message
        when RequestError
          raise RecordingStudioApi::InvalidActionInputError, error.message
        else
          raise error
        end
      end

      def recording_for(context)
        id = context&.params&.[](:recording_id)
        return if id.blank?

        RecordingStudio::Recording.find_by(id: id)
      end

      def deny!
        raise RecordingStudioApi::AuthorizationError, DENIED_MESSAGE
      end
    end
  end
end
