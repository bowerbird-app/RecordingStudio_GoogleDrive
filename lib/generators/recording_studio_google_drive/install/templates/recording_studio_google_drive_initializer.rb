# frozen_string_literal: true

RecordingStudioGoogleDrive.configure do |config|
  # config.page_size = 25
  # Oauth reads client_id and client_secret from
  # credentials.recording_studio_oauth.outbound.google_drive
  # Import-only hosts can use Drive read-only:
  # config.scopes = RecordingStudioGoogleDrive::AttachableConfiguration::DEFAULT_SCOPES

  # Optional Attachable upload provider. Loaded only when RecordingStudioAttachable
  # is bundled. Host URLs stay at /recording_studio_attachable/google_drive.
  # config.attachable.enabled = true
  # config.attachable.api_key = Rails.application.credentials.dig(:google_drive, :api_key)
  # config.attachable.app_id = Rails.application.credentials.dig(:google_drive, :app_id)
end
