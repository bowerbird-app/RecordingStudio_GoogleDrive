# frozen_string_literal: true

module RecordingStudioGoogleDrive
  module Attachable
    module ImportsSupport
      private

      def load_drive_page
        @query = params[:query].to_s.strip
        page = drive_listing_page
        @files = listed_files(page)
        @next_page_token = page.next_cursor
      end

      def drive_listing_page
        client = google_drive_client
        cursor = params[:page_token]
        page_size = attachable_config.page_size
        if @query.present?
          client.search(query: @query, cursor: cursor, page_size: page_size)
        else
          client.list(cursor: cursor, page_size: page_size)
        end
      end

      def listed_files(page)
        Array(page.entries).filter_map do |file|
          next if file.respond_to?(:folder?) && file.folder?

          { "id" => file.id, "name" => file.name, "mimeType" => file.mime_type, "webViewLink" => file.web_view_link }
        end
      end

      def selected_attachments
        Array(params[:file_ids]).filter_map { |selection| file_id_attachment(selection) }
      end

      def file_id_attachment(selection)
        return string_attachment(selection) if selection.is_a?(String)
        return unless selection.is_a?(Hash) || selection.is_a?(ActionController::Parameters)

        id = selection[:id] || selection["id"]
        return if id.blank?

        {
          provider_payload: payload_ids(id, nested_resource_key(selection)),
          name: selection[:name] || selection["name"]
        }
      end

      def string_attachment(selection)
        { provider_payload: { "id" => selection } } if selection.present?
      end

      def payload_ids(id, resource_key)
        { "id" => id.to_s, "resource_key" => resource_key }.compact
      end

      def nested_resource_key(selection)
        selection[:resource_key] || selection["resource_key"] || selection[:resourceKey] || selection["resourceKey"]
      end

      def handle_index_drive_error(error)
        return render_disconnected(reconnect: true) if Integration.reconnect_required?(error)
        raise unless Integration.request_error?(error)

        @query = params[:query].to_s.strip
        @files = []
        @next_page_token = nil
        flash.now[:alert] = error.message
        render :index, status: :bad_gateway
      end

      def handle_create_drive_error(error)
        return respond_to_reconnect_error if Integration.reconnect_required?(error)
        raise unless Integration.request_error?(error)

        respond_to_request_error(error)
      end

      def respond_to_request_error(error)
        respond_to do |format|
          format.json { render json: { error: error.message }, status: :unprocessable_content }
          format.html do
            redirect_to google_drive.recording_imports_path(@recording, upload_flow_params), alert: error.message
          end
        end
      end

      def respond_to_reconnect_error
        respond_to do |format|
          format.json { render json: reconnect_json, status: :unauthorized }
          format.html { render_disconnected(reconnect: true) }
        end
      end

      def reconnect_json
        { error: reconnect_message }.merge(provider_connect_payload(needs_auth: true, reconnect: true))
      end

      def reconnect_message
        RecordingStudioAttachable::Copy.t(
          "providers.reconnect_to_continue",
          provider: provider_label,
          default: "Reconnect #{provider_label} to continue"
        )
      end

      def render_disconnected(reconnect: google_drive_reconnect?)
        @query = params[:query].to_s.strip
        @files = []
        @next_page_token = nil
        @show_connect = true
        @reconnect = reconnect
        render :index
      end
    end
  end
end
