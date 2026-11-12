# frozen_string_literal: true

module RecordingStudioGoogleDrive
  module Api
    module Registration
      API = :public
      OPENAPI_TAGS = ["Google Drive"].freeze
      LIST_NAME = :"google_drive.list"
      SEARCH_NAME = :"google_drive.search"
      IMPORT_NAME = :"google_drive.import"

      module_function

      def register!
        register_import!
        register_list!
        register_search!
      end

      def register_list!
        register_endpoint!(
          LIST_NAME,
          http_verb: :get,
          path: "google_drive/list",
          handler: List,
          openapi: openapi("Google Drive - List", list_description, Contracts.list_parameters),
          input_contract: Contracts.list
        )
      end

      def register_search!
        register_endpoint!(
          SEARCH_NAME,
          http_verb: :get,
          path: "google_drive/search",
          handler: Search,
          openapi: openapi("Google Drive - Search", search_description, Contracts.search_parameters),
          input_contract: Contracts.search
        )
      end

      def register_import!
        register_endpoint!(
          IMPORT_NAME,
          http_verb: :post,
          path: "google_drive/import",
          handler: Import,
          openapi: openapi("Google Drive - Import", import_description).merge(
            request_body: Contracts.import_request_body
          ),
          input_contract: Contracts.import
        )
      end

      def register_endpoint!(name, **)
        return unless registrable?(name)

        RecordingStudioApi.register_endpoint(name, api: API, **)
      end

      def registrable?(name)
        !already_registered?(name)
      end

      def already_registered?(name)
        RecordingStudioApi.registered_endpoint(name, api: API).present?
      end

      def openapi(summary, description, parameters = nil)
        metadata = { tags: OPENAPI_TAGS, title: summary, summary: summary, description: description }
        metadata[:parameters] = parameters if parameters
        metadata
      end

      def list_description
        "Lists Google Drive files for the workspace connected to the recording. " \
          "Same Accessible upload permission as attaching from Drive in the UI."
      end

      def search_description
        "Searches Google Drive file names for the workspace connected to the recording. " \
          "Same Accessible upload permission as attaching from Drive in the UI."
      end

      def import_description
        "Imports Google Drive files onto the recording through Attachable. " \
          "Same Accessible upload permission as attaching from Drive in the UI."
      end
    end
  end
end
