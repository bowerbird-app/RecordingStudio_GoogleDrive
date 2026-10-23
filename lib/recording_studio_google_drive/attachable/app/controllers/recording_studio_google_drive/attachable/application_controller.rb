# frozen_string_literal: true

module RecordingStudioGoogleDrive
  module Attachable
    class ApplicationController < RecordingStudioAttachable::ProviderController
      self.upload_provider_key = :google_drive

      helper_method :google_drive_connected?, :google_drive_reconnect?, :oauth_connect_path,
                    :connect_form_fields

      private

      def attachable_config
        RecordingStudioGoogleDrive.configuration.attachable
      end

      def ensure_google_drive_enabled!
        return if attachable_config.enabled?

        raise RecordingStudioAttachable::DependencyUnavailableError,
              RecordingStudioAttachable::Copy.t(
                "providers.not_available",
                provider: provider_label,
                default: "#{provider_label} isn't available right now"
              )
      end

      def ensure_picker_configured!
        return if attachable_config.picker_configured?

        raise RecordingStudioAttachable::DependencyUnavailableError,
              I18n.t(
                "recording_studio.google_drive.picker_requires_config",
                default: "Google Drive picker needs an API key and app id"
              )
      end

      def authorize_google_drive_upload!
        authorize_provider_upload!
      end

      def google_drive_root
        Integration.root_for(@recording || find_recording)
      end

      def google_drive_client
        Integration.client(root: google_drive_root, actor: current_attachable_actor)
      end

      def google_drive_connected?
        Integration.connection(root: google_drive_root, actor: current_attachable_actor).present?
      end

      def google_drive_reconnect?
        false
      end

      def oauth_connect_path
        Integration.oauth_connect_path
      end

      def connect_return_to(popup:)
        if popup
          google_drive.recording_connected_path(@recording, popup: 1, **upload_flow_params)
        else
          google_drive.recording_imports_path(@recording, **upload_flow_params)
        end
      end

      def connect_form_fields
        {
          authenticity_token: form_authenticity_token,
          owner: "user",
          return_to: connect_return_to(popup: params[:popup].to_s == "1" || embedded_upload_provider_request?)
        }
      end

      def disconnect_google_drive_path
        connection_id = Integration.connection_id_for(root: google_drive_root, actor: current_attachable_actor)
        Integration.oauth_disconnect_path(
          connection_id,
          return_to: google_drive.recording_imports_path(@recording, upload_flow_params)
        )
      end
    end
  end
end
