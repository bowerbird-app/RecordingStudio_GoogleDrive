# frozen_string_literal: true

module RecordingStudioGoogleDrive
  module Attachable
    class ConnectController < ApplicationController
      def show
        authorize_google_drive_upload!
        ensure_google_drive_enabled!
        @reconnect = google_drive_reconnect?
        render :show
      rescue RecordingStudioAttachable::DependencyUnavailableError => e
        dependency_unavailable_alert(e)
      end

      def complete
        authorize_google_drive_upload!
        ensure_google_drive_enabled!
        render_provider_auth_complete(reload_url: connect_reload_url)
      rescue RecordingStudioAttachable::DependencyUnavailableError => e
        dependency_unavailable_alert(e)
      end

      def destroy
        authorize_google_drive_upload!
        ensure_google_drive_enabled!
        redirect_after_disconnect
      rescue RecordingStudioAttachable::DependencyUnavailableError => e
        dependency_unavailable_alert(e)
      end

      private

      def connect_reload_url
        google_drive.recording_imports_path(@recording, **upload_flow_params, embed: "modal")
      end

      def redirect_after_disconnect
        path = disconnect_google_drive_path
        return redirect_to(path, status: :temporary_redirect) if path.present?

        redirect_to google_drive.recording_imports_path(@recording, upload_flow_params),
                    alert: RecordingStudioAttachable::Copy.t(
                      "providers.disconnect_failed",
                      provider: provider_label,
                      default: "#{provider_label} isn't connected."
                    )
      end
    end
  end
end
