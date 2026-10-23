# frozen_string_literal: true

require "stringio"

module RecordingStudioGoogleDrive
  module Attachable
    class RemoteImport
      DESCRIPTION = "Imported from Google Drive"

      def self.call(parent_recording:, attachments:, actor: nil, impersonator: nil, context: nil)
        new(
          parent_recording: parent_recording,
          attachments: attachments,
          actor: actor,
          impersonator: impersonator,
          context: context
        ).call
      end

      def initialize(parent_recording:, attachments:, actor: nil, impersonator: nil, context: nil)
        @parent_recording = parent_recording
        @attachments = Array(attachments)
        @actor = actor
        @impersonator = impersonator
        @context = context
      end

      def call
        raise ArgumentError, blank_selection_message if selections.empty?

        RecordingStudioAttachable::Services::ImportRemoteFiles.call(
          parent_recording: parent_recording,
          provider_key: Attachable::PROVIDER_KEY,
          actor: actor,
          impersonator: impersonator,
          payloads: selections.map { |selection| payload_for(selection) }
        )
      end

      private

      attr_reader :parent_recording, :attachments, :actor, :impersonator, :context

      def selections
        @selections ||= attachments.filter_map { |attachment| RemoteImportSelection.from(attachment) }
      end

      def drive_client
        Integration.client(root: Integration.root_for(parent_recording), actor: actor)
      end

      def blank_selection_message
        I18n.t(
          "recording_studio.google_drive.select_at_least_one",
          default: "Select at least one file"
        )
      end

      def payload_for(selection)
        client = drive_client
        metadata = fetch_metadata(selection, client)
        reject_oversized!(metadata)
        named_payload(selection, client, metadata)
      end

      def named_payload(selection, client, metadata)
        name = selection.name.presence || metadata.name
        {
          download: -> { downloaded_payload(download_file(selection, client)) },
          filename: name,
          name: name,
          description: selection.description.presence || DESCRIPTION,
          metadata: import_metadata(selection, metadata)
        }
      end

      def fetch_metadata(selection, client)
        client.fetch_file(selection.id, resource_key: selection.resource_key)
      end

      def download_file(selection, client)
        client.download(selection.id, resource_key: selection.resource_key, max_bytes: max_file_size)
      end

      def max_file_size
        RecordingStudioAttachable.configuration.max_file_size
      end

      def import_metadata(selection, metadata)
        {
          external_id: metadata.id,
          external_url: (metadata.web_view_link if metadata.respond_to?(:web_view_link))
        }.compact.merge(selection.metadata)
      end

      def downloaded_payload(downloaded)
        {
          io: StringIO.new(downloaded.body),
          filename: downloaded.filename,
          content_type: downloaded.content_type,
          byte_size: downloaded.body.bytesize
        }
      end

      def reject_oversized!(metadata)
        max_bytes = max_file_size
        return if max_bytes.blank? || metadata.size.nil?
        return unless metadata.size > max_bytes

        raise ArgumentError, "Remote file exceeds maximum file size"
      end
    end

    class RemoteImportSelection
      attr_reader :id, :resource_key, :name, :description, :metadata

      def self.from(attachment)
        payload = attachment.is_a?(Hash) ? attachment : {}
        provider_payload = provider_payload_from(payload)
        id = nested_value(provider_payload, :id)
        return if id.blank?

        new(**selection_attrs(id, provider_payload, payload))
      end

      def self.provider_payload_from(payload)
        payload[:provider_payload] || payload["provider_payload"] || payload
      end

      def self.selection_attrs(id, provider_payload, payload)
        {
          id: id.to_s,
          resource_key: nested_value(provider_payload, :resource_key, :resourceKey),
          name: payload[:name].presence || payload["name"],
          description: payload[:description].presence || payload["description"],
          metadata: (payload[:metadata] || payload["metadata"] || {}).to_h.symbolize_keys
        }
      end

      def self.nested_value(source, *keys)
        return if source.nil?

        keys.lazy.map { |key| source[key] || source[key.to_s] }.find(&:present?)
      end

      def initialize(id:, resource_key:, name:, description:, metadata:)
        @id = id
        @resource_key = resource_key
        @name = name
        @description = description
        @metadata = metadata
      end
    end
  end
end
