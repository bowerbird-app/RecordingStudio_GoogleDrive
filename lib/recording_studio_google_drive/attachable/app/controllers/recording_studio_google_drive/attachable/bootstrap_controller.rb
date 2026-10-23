# frozen_string_literal: true

module RecordingStudioGoogleDrive
  module Attachable
    class BootstrapController < ApplicationController
      def show
        authorize_provider_upload!
        ensure_provider_available!
        ensure_picker_configured!

        render json: bootstrap_payload
      rescue RecordingStudioAttachable::DependencyUnavailableError => e
        render json: { error: e.message }, status: :unprocessable_content
      end

      private

      def bootstrap_payload
        return connect_bootstrap(reconnect: google_drive_reconnect?) if needs_auth?

        connected_bootstrap
      rescue StandardError => e
        raise unless Attachable.reconnect_error?(e)

        connect_bootstrap(reconnect: true)
      end

      def connect_bootstrap(reconnect:)
        provider_connect_payload(needs_auth: true, reconnect: reconnect, import_url: json_import_url)
      end

      def connected_bootstrap
        token, expires_at = Integration.picker_access(root: google_drive_root, actor: current_attachable_actor)
        provider_connect_payload(needs_auth: false, reconnect: false, import_url: json_import_url).merge(
          api_key: attachable_config.api_key,
          app_id: attachable_config.app_id,
          access_token: token,
          expires_at: (expires_at.to_i if expires_at.respond_to?(:to_i) && expires_at.to_i.positive?)
        ).compact
      end

      def json_import_url
        google_drive.recording_imports_path(@recording, format: :json, **attachment_redirect_params)
      end

      def needs_auth?
        !google_drive_connected? || google_drive_reconnect?
      end
    end
  end
end
