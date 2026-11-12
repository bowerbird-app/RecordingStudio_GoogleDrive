# frozen_string_literal: true

module RecordingStudioGoogleDrive
  module Api
    module Contracts
      module_function

      def list
        { reject_unknown: true, fields: page_fields }
      end

      def search
        { reject_unknown: true, fields: page_fields.merge(query: required_string("Drive name search.")) }
      end

      def import
        {
          reject_unknown: true,
          fields: {
            recording_id: recording_id_field("Recording to attach imported files to."),
            attachments: { type: :array, required: true, description: "Drive files to import." }
          }
        }
      end

      def list_parameters
        query_parameters(
          recording_id: ["Recording whose workspace Drive connection to use.", true],
          parent_id: ["Drive folder id to list inside.", false],
          cursor: ["Next page cursor from a previous list.", false],
          page_size: ["Page size. Uses the gem default when omitted.", false, { type: "integer" }]
        )
      end

      def search_parameters
        query_parameters(
          recording_id: ["Recording whose workspace Drive connection to use.", true],
          query: ["Drive name search.", true],
          parent_id: ["Drive folder id to search inside.", false],
          cursor: ["Next page cursor from a previous search.", false],
          page_size: ["Page size. Uses the gem default when omitted.", false, { type: "integer" }]
        )
      end

      def import_request_body
        schema = {
          type: "object",
          required: %w[recording_id attachments],
          properties: {
            recording_id: { type: "string" },
            attachments: { type: "array", items: { type: "object" } }
          }
        }
        { required: true, content: { "application/json" => { schema: schema } } }
      end

      def page_fields
        {
          recording_id: recording_id_field("Recording whose workspace Drive connection to use."),
          parent_id: optional_string("Drive folder id to list or search inside."),
          cursor: optional_string("Next page cursor from a previous list or search."),
          page_size: { type: :integer, required: false, description: "Page size. Uses the gem default when omitted." }
        }
      end

      def recording_id_field(description)
        { type: :string, required: true, allow_blank: false, description: description }
      end

      def required_string(description)
        { type: :string, required: true, allow_blank: false, description: description }
      end

      def optional_string(description)
        { type: :string, required: false, allow_blank: true, description: description }
      end

      def query_parameters(fields)
        fields.map do |name, (description, required, schema)|
          {
            name: name.to_s,
            in: "query",
            required: required,
            description: description,
            schema: schema || { type: "string" }
          }
        end
      end
    end
  end
end
