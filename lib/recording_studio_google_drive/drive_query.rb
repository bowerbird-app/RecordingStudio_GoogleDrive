# frozen_string_literal: true

module RecordingStudioGoogleDrive
  module DriveQuery
    module_function

    def build(query: nil, parent_id: nil)
      clauses = ["trashed = false"]
      clauses << "'#{escape(parent_id)}' in parents" if present?(parent_id)
      clauses << "name contains '#{escape(query)}'" if present?(query)
      clauses.join(" and ")
    end

    def escape(value)
      value.to_s.gsub("\\", "\\\\").gsub("'", "\\'")
    end

    def present?(value)
      !value.nil? && !value.to_s.empty?
    end
  end
end
