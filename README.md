# RecordingStudio Google Drive

This gem talks to the Google Drive API for Recording Studio. It lists and searches files, reads metadata, downloads files (including Google Docs export), and uploads files. It does not store OAuth tokens. It does not register as an Attachable upload source yet.

## Client

Build a client with a token provider. The provider is a callable, or an object that responds to `access_token`.

```ruby
client = RecordingStudioGoogleDrive::Client.new(
  token_provider: -> { "ya29.access-token" }
)

page = client.list_files(query: "brief", page_size: 25, parent_id: "root")
page.files
page.next_page_token

file = client.fetch_file("file-id")
downloaded = client.download_file("file-id")
uploaded = client.upload_file(
  io: File.open("notes.pdf"),
  filename: "notes.pdf",
  content_type: "application/pdf",
  parent_id: "root"
)
```

`list_files` pages with `page_token` and `next_page_token`. Search is a Drive `name contains` clause. Folders are included so callers can browse. Trashed files are excluded.

Google Docs, Sheets, Slides, and Drawings download through Drive export. Docs and Slides become PDF. Sheets become CSV. Drawings become PNG. Other files download as binary.

## Token provider

Oauth is not a dependency of this gem yet. When [RecordingStudio_Oauth outbound connections](https://github.com/bowerbird-app/RecordingStudio_Oauth/pull/62) ships, look up the token with `connection_for` and pass that connection as the provider:

```ruby
connection = RecordingStudioOauth.connection_for(
  provider: :google_drive,
  root: root_recording,
  actor: current_user
)
client = RecordingStudioGoogleDrive::Client.new(token_provider: connection)
```

`connection.access_token` is the live access token. Tests in this gem use a fake provider and stubbed HTTP. They do not call Oauth.

## Errors

Expired, revoked, and insufficient-scope tokens raise `RecordingStudioGoogleDrive::ReconnectRequired`. Callers can turn that into a reconnect state. Other Drive failures raise `RecordingStudioGoogleDrive::RequestError`. Both inherit `RecordingStudioGoogleDrive::Error`. The mapper uses HTTP status and Google's structured error fields, not free-text message matching.

## Configuration

```ruby
RecordingStudioGoogleDrive.configure do |config|
  config.page_size = 25
end
```

Default page size is 25, matching Attachable's Drive list.

## Later wiring

A later phase registers this gem into RecordingStudio_attachable with `register_upload_provider`. Another phase places it in a Plugins directory. Those changes are out of this gem's 0.1.0.

## Dummy app

`test/dummy/` is a host that boots Recording Studio so the engine loads. Sign in at `/users/sign_in` with `admin@admin.com` / `Password`. Dummy credentials use the shared RecordingStudio development master key. Set `RAILS_MASTER_KEY` or `test/dummy/config/master.key`. Do not mint a new key.

## Development

Ruby 3.3.12. Rails 8.1. Recording Studio `~> 4.2` (dummy GitHub tag `v4.7.0`).

```bash
bundle install
BUNDLE_GEMFILE=test/dummy/Gemfile bundle install
bundle exec rake test:all
```
