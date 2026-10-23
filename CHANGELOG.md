# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/), and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [0.4.0] - 2026-10-23

### Added
- Optional Attachable upload add-on. When `RecordingStudioAttachable` is present and `config.attachable.enabled` is true, this gem registers `:google_drive` with Attachable's public provider hooks.
- Attachable settings live on this gem: `RecordingStudioGoogleDrive.configure { |c| c.attachable.api_key = ... }`. Keys are `enabled`, `api_key`, `app_id`, and `page_size`.
- Google Picker launcher JS ships here and imports helpers from `recording_studio_attachable/provider_launchers`. The Picker opens only from a user click.
- Depends on `recording_studio_attachable` `>= 0.21.0, < 1.0`. Dummy pins git ref `3d3dadc9072768dba4a5a993aefaddfbe85f4502` until Attachable 0.21.0 is tagged.

### Upgrade notes
- Hosts that used Attachable's in-tree Drive keep the same mount path (`/recording_studio_attachable/google_drive`) and `google_drive_*` route helpers. Remove Attachable `config.google_drive.*` and set this gem's `config.attachable.*` instead.
- Add `recording_studio_attachable` `>= 0.21.0, < 1.0`. Pin `recording_studio_attachable/provider_launchers` and `recording_studio_google_drive/google_drive_picker_launcher` in importmap.
- Set `config.attachable.enabled = true`, `api_key`, and `app_id`. Oauth `client_id` and `client_secret` stay on `recording_studio_oauth.outbound.google_drive`.
- Import-only hosts can set `config.scopes` to `RecordingStudioGoogleDrive::AttachableConfiguration::DEFAULT_SCOPES` (`drive.readonly`). The client default remains `drive` so `upload_file` still has write access.

[0.4.0]: https://github.com/bowerbird-app/RecordingStudio_GoogleDrive/releases/tag/v0.4.0

## [0.3.0] - 2026-10-23

### Added
- `RecordingStudioGoogleDrive.picker_access_token(root:, actor:)` returns the current Oauth access token for the Google Picker. It uses `TokenStore` and `RecordingStudioOauth.connection_for`. Oauth refreshes expired tokens. Missing, revoked, needs-reconnect, or failed refresh raises `ReconnectRequired`.

### Upgrade notes
- Hand this token to the browser for the Google Picker only. Do not log it or persist it. Drive API calls still go through `Client.for`.

## [0.2.0] - 2026-10-22

### Added
- Depends on `recording_studio_oauth` `>= 0.14.1, < 1.0`. Dummy and the gem Gemfile pin git tag `v0.14.1`.
- Registers `:google_drive` with Oauth's outbound provider registry (authorize, token, revoke, Drive scopes, PKCE, refresh).
- `Client.for(root:, actor:)` and `TokenStore` resolve a live access token through `RecordingStudioOauth.connection_for`. Oauth refreshes expired tokens. Missing, revoked, or failed refresh raises `ReconnectRequired`.
- Dummy Connect, Disconnect, and Reconnect for Google Drive through Oauth's outbound flow, using a local fake provider.

### Changed
- Tokens come from Oauth outbound connections. The client still accepts a test `token_provider` so the suite makes no network calls.

### Upgrade notes
- Add Oauth `>= 0.14.1, < 1.0` and run its install plus migrations.
- Set `credentials.recording_studio_oauth.outbound.google_drive.client_id` and `client_secret` in the host secret store. Do not commit the values.
- Build clients with `Client.for(root:, actor:)` (or `Client.new(root:, actor:)`). A callable `token_provider` remains valid for tests.
- No connection, or a refresh that Oauth cannot complete, raises `ReconnectRequired`. Ask the person to Connect again.

## [0.1.0] - 2026-10-22

### Added
- `RecordingStudioGoogleDrive::Client` for Drive list, search, metadata, download, and upload.
- Shared client shape with RecordingStudio Dropbox: `AccessToken`, `Page`, `DownloadedFile`, `Error`, `ReconnectRequired`, and `RequestError`.
- `search(query:, cursor: nil, page_size: nil)` and `list(parent_id: nil, cursor: nil, page_size: nil)` keyword arguments.
- `AccessToken.new(provider)` raises `ArgumentError` unless the provider responds to `call` or `access_token`. A raw String is a misconfiguration. `#to_s` calls `call` first, else `access_token`. A blank token raises `ReconnectRequired`.
- `Page = Data.define(:entries, :next_cursor)`. `more?` is false for a nil or empty cursor.
- `DownloadedFile = Data.define(:body, :filename, :content_type)`. `content_type` is always a member and may be nil.
- `upload_file` keeps `content_type:` required.
- `RequestError.new(message = nil, status:, code:)` with `status` and `code` readers. `Error < StandardError`, `ReconnectRequired < Error`, `RequestError < Error`.
- `RecordingStudioGoogleDrive.configure` returns the configuration. Default page size is 25.

### Upgrade notes
- This is the first release of `recording_studio_google_drive`. Add the gem, then build a client with a token provider. Do not add Oauth as a dependency until that gem is released.
- Call `search` with `query:` (not a positional argument). HTTP 401, `invalid_grant`, and `invalid_token` still raise `ReconnectRequired`. `unauthorized_client` raises `RequestError`.

[0.3.0]: https://github.com/bowerbird-app/RecordingStudio_GoogleDrive/releases/tag/v0.3.0
[0.2.0]: https://github.com/bowerbird-app/RecordingStudio_GoogleDrive/releases/tag/v0.2.0
[0.1.0]: https://github.com/bowerbird-app/RecordingStudio_GoogleDrive/releases/tag/v0.1.0
