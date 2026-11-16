# frozen_string_literal: true

RecordingStudioAccessible.configure do |config|
  config.access_actor_types = [
    "User",
    "RecordingStudioApi::ApiClient",
    "RecordingStudioOauth::OauthAuthorization"
  ]

  # Staff pages allow an actor who holds admin on the Studio Workspace root.
  config.admin_root_resolver = lambda do
    workspace = Workspace.find_by(name: "Studio Workspace")
    next unless workspace

    RecordingStudio::Recording.kept.find_by(recordable: workspace, parent_recording_id: nil)
  end
end
