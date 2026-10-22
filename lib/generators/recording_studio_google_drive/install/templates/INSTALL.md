RecordingStudioGoogleDrive install complete.

Next steps:

1. Review config/initializers/recording_studio_google_drive.rb and set any required options.
2. If you use environment-specific settings, create config/recording_studio_google_drive.yml.
3. Install Recording Studio Oauth and migrate. Set `recording_studio_oauth.outbound.google_drive.client_id` and `client_secret` in credentials. Name the keys. Do not commit the values.
4. Build a client with `RecordingStudioGoogleDrive::Client.for(root:, actor:)`. Oauth stores the token. This gem does not add product screens.
