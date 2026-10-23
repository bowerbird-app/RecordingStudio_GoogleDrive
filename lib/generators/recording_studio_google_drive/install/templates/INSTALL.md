RecordingStudioGoogleDrive install complete.

Next steps:

1. Review config/initializers/recording_studio_google_drive.rb and set any required options.
2. If you use environment-specific settings, create config/recording_studio_google_drive.yml.
3. Install Recording Studio Oauth and migrate. Set `recording_studio_oauth.outbound.google_drive.client_id` and `client_secret` in credentials. Name the keys. Do not commit the values.
4. Build a client with `RecordingStudioGoogleDrive::Client.for(root:, actor:)`. Oauth stores the token.
5. For upload-page Drive import, add Recording Studio Attachable `>= 0.21.0, < 1.0`, mount it, and set `config.attachable.enabled`, `api_key`, and `app_id`. Pin `recording_studio_attachable/provider_launchers` and `recording_studio_google_drive/google_drive_picker_launcher` in importmap. The Drive engine mounts at `/google_drive` under Attachable, so existing `google_drive_*` route helpers stay the same.
