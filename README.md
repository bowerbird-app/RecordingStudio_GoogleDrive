# RecordingStudio Google Drive

This gem talks to the Google Drive API for Recording Studio. It lists and searches files, reads metadata, downloads files (including Google Docs export), and uploads files. Tokens live on Recording Studio Oauth outbound connections. This gem does not store them.

## Setup

1. Add the gem and pin Oauth `v0.14.1`.
2. Run `bin/rails generate recording_studio_google_drive:install`.
3. Install and migrate Recording Studio Oauth (`recording_studio_oauth:install` and `recording_studio_oauth:migrations`).
4. Set Google OAuth app credentials. Name the keys. Do not put the values in git, chat, or this README.

```yaml
# Rails credentials. Name the keys. Set the values in the host secret store.
recording_studio_oauth:
  outbound:
    google_drive:
      client_id:
      client_secret:
```

The gem registers `:google_drive` with Oauth on boot: authorize URL, token URL, revoke URL, Drive scopes, PKCE, and refresh. `access_type=offline` and `prompt=consent` are sent so Google issues a refresh token. Oauth reads `client_id` and `client_secret` from `recording_studio_oauth.outbound.google_drive` unless you pass them in configuration.

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

page = client.search(query: "brief", cursor: page.next_cursor)
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

`list` and `search` return a `Page`. Ask for the next page with `cursor:`. Search is a Drive `name contains` clause. Folders are included so callers can browse. Trashed files stay out.

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

## Dummy app

`test/dummy/` is a host that boots Recording Studio and Oauth. Sign in at `/users/sign_in` with `admin@admin.com` / `Password`. The home page Connects, Disconnects, and Reconnects Google Drive through Oauth's outbound flow. Dummy registers the same `:google_drive` provider against `/fake_oauth/*`, not real Google credentials.

## Development

Ruby 3.3.12. Rails 8.1. Recording Studio `~> 4.2` (dummy GitHub tag `v4.7.0`). Oauth `>= 0.14.1, < 1.0` (dummy GitHub tag `v0.14.1`).

```bash
bundle install
BUNDLE_GEMFILE=test/dummy/Gemfile bundle install
bundle exec rake test:all
```
