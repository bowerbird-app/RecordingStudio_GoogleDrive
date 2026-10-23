# frozen_string_literal: true

module RecordingStudioGoogleDrive
  module Attachable
    module ImportsSupport
      include ImportsErrors

      private

      def load_drive_page
        @query = params[:query].to_s.strip
        page = browser_location.fetch_page(
          client: google_drive_client,
          cursor: params[:page_token],
          page_size: attachable_config.page_size
        )
        @files = listed_files(page)
        @next_page_token = page.next_cursor
        assign_browser_location
      end

      def listed_files(page)
        Array(page.entries).map do |file|
          BrowserRow.from_drive_file(file, open_url: browser_location.open_folder_url(file))
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

      def render_disconnected(reconnect: google_drive_reconnect?)
        @query = params[:query].to_s.strip
        @files = []
        @next_page_token = nil
        @show_connect = true
        @reconnect = reconnect
        assign_browser_location
        render :index
      end

      def assign_browser_location
        @current_path = browser_location.current_path
        @parent_url = browser_location.parent_url
        @browse_query = browse_query
      end

      def browse_query
        upload_flow_params.merge(browser_location.query_params)
      end

      def browser_location
        @browser_location ||= BrowserLocation.new(
          folder_ids: params[:folder_ids],
          folder_names: params[:folder_names],
          query: @query || params[:query],
          root_name: provider_label,
          url_builder: method(:folder_imports_url)
        )
      end

      def folder_imports_url(ids:, names:)
        google_drive.recording_imports_path(@recording, **folder_query(ids, names))
      end

      def folder_query(ids, names)
        upload_flow_params.merge(
          query: (@query || params[:query]).to_s.presence,
          folder_ids: ids.presence,
          folder_names: names.presence
        ).compact
      end
    end
  end
end
