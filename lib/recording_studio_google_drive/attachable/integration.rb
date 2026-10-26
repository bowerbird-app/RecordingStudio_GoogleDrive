# frozen_string_literal: true

module RecordingStudioGoogleDrive
  module Attachable
    module Integration
      module_function

      def provider_key
        RecordingStudioGoogleDrive.configuration.oauth_provider_key
      end

      def client(root:, actor:)
        RecordingStudioGoogleDrive::Client.for(root: root, actor: actor)
      end

      def connection(root:, actor:)
        return unless defined?(RecordingStudioOauth)

        RecordingStudioOauth.connection_for(provider: provider_key, root: root, actor: actor)
      end

      def connection_id_for(root:, actor:)
        connection(root: root, actor: actor)&.id
      end

      def picker_access(root:, actor:)
        token = RecordingStudioGoogleDrive.picker_access_token(root: root, actor: actor)
        expires_at = connection(root: root, actor: actor)&.expires_at
        [token, expires_at]
      end

      def request_error?(error)
        error.is_a?(RecordingStudioGoogleDrive::RequestError)
      end

      def root_for(recording)
        return recording unless recording.respond_to?(:root_recording)

        recording.root_recording || recording
      end

      def oauth_connect_path
        oauth_routes&.outbound_connect_path(provider: provider_key)
      end

      def oauth_disconnect_path(connection_id, return_to:)
        return if connection_id.blank?

        oauth_routes&.outbound_connection_path(connection_id, return_to: return_to)
      end

      def connect_payload(recording:, context:)
        helpers = context.google_drive
        {
          url: oauth_connect_path,
          method: "post",
          fields: connect_fields(recording, helpers, context),
          fallback_url: helpers.recording_connect_path(recording)
        }
      end

      def connect_fields(recording, helpers, context)
        {
          authenticity_token: context.provider_csrf_token,
          owner: "root",
          root_recording_id: root_for(recording)&.id,
          return_to: helpers.recording_connected_path(recording, popup: 1)
        }
      end

      def oauth_routes
        return unless defined?(RecordingStudioOauth)

        RecordingStudioOauth::Engine.routes.url_helpers
      end
    end
  end
end
