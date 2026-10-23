# frozen_string_literal: true

module RecordingStudioGoogleDrive
  module Attachable
    class BrowserLocation
      def initialize(folder_ids:, folder_names:, query:, root_name:, url_builder:)
        @folder_ids = Array(folder_ids).map(&:presence).compact
        @folder_names = Array(folder_names).map(&:to_s)
        @query = query.to_s.presence
        @root_name = root_name
        @url_builder = url_builder
      end

      def current_folder_id
        folder_ids.last
      end

      def current_path
        crumbs = [{ name: root_name, url: url_for(ids: [], names: []) }]
        folder_ids.each_with_index do |id, index|
          crumbs << {
            name: folder_names[index].presence || id,
            url: url_for(ids: folder_ids[0..index], names: folder_names[0..index])
          }
        end
        crumbs
      end

      def parent_url
        return if folder_ids.empty?

        url_for(ids: folder_ids[0...-1], names: folder_names[0...-1])
      end

      def query_params
        {
          query: query,
          folder_ids: folder_ids.presence,
          folder_names: folder_names.presence
        }.compact
      end

      def open_folder_url(file)
        return unless file.respond_to?(:folder?) && file.folder?

        url_for(ids: folder_ids + [file.id], names: folder_names + [file.name])
      end

      def fetch_page(client:, cursor:, page_size:)
        if query.present?
          client.search(query: query, cursor: cursor, page_size: page_size, parent_id: current_folder_id)
        else
          client.list(cursor: cursor, page_size: page_size, parent_id: current_folder_id)
        end
      end

      private

      attr_reader :folder_ids, :folder_names, :query, :root_name, :url_builder

      def url_for(ids:, names:)
        url_builder.call(ids: ids, names: names)
      end
    end
  end
end
