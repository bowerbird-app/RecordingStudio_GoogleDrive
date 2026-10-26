# RecordingStudio Google Drive

This gem talks to the Google Drive API for Recording Studio. It lists and searches files, reads metadata, downloads files (including Google Docs export), and uploads files. Tokens live on Recording Studio Oauth outbound connections. This gem does not store them.

## Setup

1. Add the gem and pin Oauth `v0.17.0`.
2. Run `bin/rails generate recording_studio_google_drive:install`.
3. Install and migrate Recording Studio Oauth (`recording_studio_oauth:install` and `recording_studio_oauth:migrations`).
4. Register Google Drive from the host initializer. The gem does not register itself.
5. Set Google OAuth app credentials. Name the keys. Do not put the values in git, chat, or this README.

```yaml
# Rails credentials. Name the keys. Set the values in the host secret store.
recording_studio_oauth:
  outbound:
    google_drive:
      client_id:
      client_secret:
```

Google Drive is a root plugin. A workspace admin connects it once for the workspace. The host registers it with Oauth:

```ruby
# config/initializers/recording_studio_google_drive.rb
RecordingStudioGoogleDrive.register_oauth_provider
```

That call uses Oauth's public registry with `kind: :root`. It skips registration only when both `client_id` and `client_secret` are blank (this gem's config, keyword overrides, or `recording_studio_oauth.outbound.google_drive`), so a host without Drive credentials still boots. Other Oauth errors still raise. Authorize URL, token URL, revoke URL, Drive scopes, PKCE, and refresh are the defaults. `access_type=offline` and `prompt=consent` are sent so Google issues a refresh token.

## Client

Look up a live token through Oauth, then build a client:

```ruby
client = RecordingStudioGoogleDrive::Client.for(
  root: root_recording,
  actor: current_user
)

page = client.list(parent_id: "root", page_size: 25)
page.entries
page.next_cursor
page.more?

page = client.search(query: "brief", cursor: page.next_cursor, parent_id: "folder-id")
file = client.fetch_file("file-id")
downloaded = client.download("file-id")
uploaded = client.upload_file(
  io: File.open("notes.pdf"),
  filename: "notes.pdf",
  content_type: "application/pdf",
  parent_id: "root"
)
```

`Client.for` calls `RecordingStudioOauth.connection_for(provider:, root:, actor:)`. Oauth refreshes an expired token. No connection, a revoked connection, or a failed refresh raises `ReconnectRequired`. Tokens are never written to the session, logs, or exception messages.

The Google Picker in the browser needs that same short-lived token. Ask for it with `picker_access_token`. Hand it to the Picker only. Do not log it or persist it. Drive list, search, download, and upload still go through `Client`.

```ruby
token = RecordingStudioGoogleDrive.picker_access_token(
  root: root_recording,
  actor: current_user
)
```

No connection, a connection that needs reconnecting, or a failed refresh raises `ReconnectRequired`.

Tests and hosts that already have a token object can still pass `token_provider:` (a callable, or an object that responds to `access_token`). A raw String is a misconfiguration. A blank token at request time raises `ReconnectRequired`.

`list` and `search` return a `Page`. Ask for the next page with `cursor:`. Search is a Drive `name contains` clause. Pass `parent_id:` to search or list inside a folder. Folders are included so callers can browse. Trashed files stay out. `download` takes `max_bytes:` to abort an oversize body before it is fully read. Native Docs, Sheets, and Slides exports have no metadata size, so that cap still applies.

Download returns a `DownloadedFile` with `body`, `filename`, and `content_type`. Google Docs, Sheets, Slides, and Drawings go through Drive export. Docs and Slides become PDF. Sheets become CSV. Drawings become PNG. Other files download as binary.

## Errors

`RecordingStudioGoogleDrive::Error` is the base. Expired, revoked, insufficient-scope, `invalid_token`, and `invalid_grant` tokens raise `ReconnectRequired`. `unauthorized_client` and other Drive failures raise `RequestError`, which exposes `status` and `code`. The mapper uses HTTP status and Google's structured error `status`. It does not copy the response body into the message.

## Configuration

```ruby
RecordingStudioGoogleDrive.configure do |config|
  config.page_size = 25
end
```

Default page size is 25. Dummy and tests point authorize, token, and revoke URLs at a local fake provider so they never call Google.

## Attachable upload add-on

This gem owns Google Drive import for Recording Studio Attachable. Attachable stays provider-neutral. This gem does not depend on Attachable. The add-on loads only when `RecordingStudioAttachable` `>= 0.21.0` is present (`ActiveSupport.on_load(:recording_studio_attachable)`). Dummy and CI pin Attachable in the Gemfile.

1. Optionally add `recording_studio_attachable` `>= 0.21.0, < 1.0`. Dummy and CI pin Attachable to tag `v0.21.0`.
2. Enable Attachable on the recordable types that should accept files.
3. Mount Attachable. This gem registers adapter routes at `/google_drive` (`as: :google_drive`), so host URLs and route helpers stay the same as Attachable's old in-tree Drive.
4. Pin importmap modules `recording_studio_attachable/provider_launchers` and `recording_studio_google_drive/google_drive_picker_launcher`.
5. Configure the picker:

```ruby
RecordingStudioGoogleDrive.configure do |config|
  config.attachable.enabled = true
  config.attachable.api_key = Rails.application.credentials.dig(:google_drive, :api_key)
  config.attachable.app_id = Rails.application.credentials.dig(:google_drive, :app_id)
end
```

Oauth `client_id` and `client_secret` stay on `recording_studio_oauth.outbound.google_drive`. Name the keys. Do not put the values in git.

The add-on registers `:google_drive` with `register_upload_provider` (`connect:`, `reconnect_error:`). `connect` takes `recording:` and `context:`. `remote_importer` takes `parent_recording:`, `attachments:`, `actor:`, `impersonator:`, and `context:`. Auth is `needs_auth` on bootstrap. Connect is `{ url, method, fields, fallback_url }` — use `connect.fields.authenticity_token`, not a flat token. HTML browse uses Attachable's `_remote_file_browser` locals (`content_type`, `kind: :file` / `:folder`, `open_url`, `current_path`, `parent_url`, `path`). Controllers inherit `RecordingStudioAttachable::ProviderController`. Imports go through `RecordingStudioAttachable::Services::ImportRemoteFiles`. Drive bytes come from `Client#download`. URL downloads in Attachable go through `SafeRemoteFetch.call(..., max_bytes: configuration.max_file_size)`. Connect JSON uses `ProviderConnect.payload`. Drive-only copy such as `picker_requires_config` lives in this gem's locale file. Adapter routes register once for `:google_drive`.

Import-only hosts can set `config.scopes` to `RecordingStudioGoogleDrive::AttachableConfiguration::DEFAULT_SCOPES` (`https://www.googleapis.com/auth/drive.readonly`).

## Dummy app

`test/dummy/` is a host that boots Recording Studio, Oauth, Attachable, and this add-on. Sign in at `/users/sign_in` with `admin@admin.com` / `Password`. The home page Connects, Disconnects, and Reconnects Google Drive through Oauth's outbound flow.

Boot the dummy from `test/dummy`:

```bash
bundle install
bin/rails db:setup
bin/dev
```

Without Google secrets, dummy uses `/fake_oauth/*`. For a real Drive import in the browser, set `recording_studio_oauth.outbound.google_drive` (`client_id`, `client_secret`) and picker keys on `attachable.google_drive` or `google_drive` (`api_key`, `app_id`), or the ENV vars `GOOGLE_DRIVE_CLIENT_ID`, `GOOGLE_DRIVE_CLIENT_SECRET`, `GOOGLE_DRIVE_API_KEY`, and `GOOGLE_DRIVE_APP_ID`. `RAILS_DEVELOPMENT_HOSTS` adds allowed hosts.

After seed, open `/recording_studio_attachable/recordings/<page-recording-id>/attachments/upload` on the seeded Getting Started page. Seeds print that path.

## Development

Ruby 3.3.12. Rails 8.1. Recording Studio `~> 4.2` (dummy GitHub tag `v4.7.0`). Oauth `>= 0.17.0, < 1.0` (dummy GitHub tag `v0.17.0`). Attachable is optional (`>= 0.21.0, < 1.0`; dummy and CI pin tag `v0.21.0`). Dummy and CI also pin API `v0.16.0`, Logs `v0.7.0`, and Metrics `v0.6.1`.

```bash
bundle install
BUNDLE_GEMFILE=test/dummy/Gemfile bundle install
bundle exec rake test:all
```
