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
  # Recording Studio 6.5 closes writes unless the host sets an authorizer.
  # This dummy records during boot and tests without a signed-in actor.
  config.allow_unauthorized_writes = true if config.respond_to?(:allow_unauthorized_writes=)
  config.event_notifications_enabled = true
  config.idempotency_mode = :return_existing
  config.recordable_dup_strategy = :dup
end
