# frozen_string_literal: true

require "recording_studio_google_drive/attachable/engine"
require "recording_studio_google_drive/attachable/integration"
require "recording_studio_google_drive/attachable/remote_import"
require "recording_studio_google_drive/attachable/browser_row"
require "recording_studio_google_drive/attachable/browser_location"

module RecordingStudioGoogleDrive
  module Attachable
    LAUNCHER_MODULE = "recording_studio_google_drive/google_drive_picker_launcher"
    PROVIDER_KEY = :google_drive

    module_function

    def register_upload_provider!
      return unless RecordingStudioGoogleDrive.configuration.attachable.enabled?

      RecordingStudioAttachable.register_upload_provider(PROVIDER_KEY, **upload_provider_options)
    end

    def upload_provider_options
      picker_options.merge(import_options)
    end

    def picker_options
      {
        label: "Google Drive",
        icon: "cloud",
        strategy: :client_picker,
        launcher: "google_drive",
        launcher_module: LAUNCHER_MODULE
      }.merge(picker_urls)
    end

    def picker_urls
      {
        url: method(:bootstrap_url),
        bootstrap_url: method(:bootstrap_url),
        import_url: method(:import_url),
        allowed_payload_keys: %w[id resource_key]
      }
    end

    def import_options
      {
        remote_importer: method(:remote_importer),
        connect: method(:connect_payload),
        reconnect_error: method(:reconnect_error?),
        visible: method(:visible?)
      }
    end

    def bootstrap_url(route_helpers:, recording:)
      route_helpers.google_drive.recording_bootstrap_path(recording, format: :json)
    end

    def import_url(route_helpers:, recording:)
      route_helpers.google_drive.recording_imports_path(recording, format: :json)
    end

    def remote_importer(parent_recording:, attachments:, actor: nil, impersonator: nil, **)
      RemoteImport.call(
        parent_recording: parent_recording,
        attachments: attachments,
        actor: actor,
        impersonator: impersonator
      )
    end

    def connect_payload(*, recording:, context:)
      Integration.connect_payload(recording: recording, context: context)
    end

    def reconnect_error?(error)
      error.is_a?(RecordingStudioGoogleDrive::ReconnectRequired)
    end

    def visible?(**)
      RecordingStudioGoogleDrive.configuration.attachable.picker_configured?
    end

    def register_adapter_routes!
      return if adapter_routes_registered?

      @adapter_routes_registered = true
      RecordingStudioAttachable.register_adapter_routes(:google_drive) do
        mount RecordingStudioGoogleDrive::Attachable::Engine, at: "/google_drive", as: :google_drive
      end
    end

    def adapter_routes_registered?
      @adapter_routes_registered == true
    end
  end
end

ActiveSupport.on_load(:recording_studio_attachable) do
  RecordingStudioGoogleDrive::Attachable.register_adapter_routes!
end
