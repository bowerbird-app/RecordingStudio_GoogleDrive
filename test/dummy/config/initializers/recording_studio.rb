# frozen_string_literal: true

RecordingStudio.configure do |config|
  config.recordable_types = [
    "Workspace",
    "Folder",
    "Page",
    "AdminRoot",
    "RecordingStudioSiteSettings::SiteSetting",
    "RecordingStudioAttachable::Attachment"
  ]

  config.require_recordable_declarations = true
  config.app_name = "Google Drive Demo" if config.respond_to?(:app_name=)
  config.actor = -> { Current.actor }
  # Core 7 denies a write unless this callback allows it.
  # A present actor may write, including a new root (root_recording is nil).
  config.authorize_write = ->(actor:, **) { actor.present? }
  config.event_notifications_enabled = true
  config.idempotency_mode = :return_existing
  config.recordable_dup_strategy = :dup
end
