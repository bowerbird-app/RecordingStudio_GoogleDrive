# RecordingStudio Google Drive

This gem talks to the Google Drive API for Recording Studio. It lists and searches files, reads metadata, downloads files (including Google Docs export), and uploads files. It does not store OAuth tokens.

## Client

Build a client with a token provider. The provider is a callable, or an object that responds to `access_token`. A raw String is a misconfiguration. A blank token at request time raises `ReconnectRequired`.

```ruby
client = RecordingStudioGoogleDrive::Client.new(
  token_provider: -> { "ya29.access-token" }
)

page = client.list(parent_id: "root", page_size: 25)
page.entries
page.next_cursor
page.more?

page = client.search("brief", cursor: page.next_cursor)
file = client.fetch_file("file-id")
downloaded = client.download("file-id")
uploaded = client.upload_file(
  io: File.open("notes.pdf"),
  filename: "notes.pdf",
  content_type: "application/pdf",
  parent_id: "root"
)
```

`list` and `search` return a `Page`. Ask for the next page with `cursor:`. Search is a Drive `name contains` clause. Folders are included so callers can browse. Trashed files stay out.

Download returns a `DownloadedFile` with `body`, `filename`, and `content_type`. Google Docs, Sheets, Slides, and Drawings go through Drive export. Docs and Slides become PDF. Sheets become CSV. Drawings become PNG. Other files download as binary.

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

`RecordingStudioGoogleDrive::Error` is the base. Expired, revoked, insufficient-scope, and `invalid_grant` tokens raise `ReconnectRequired`. Other Drive failures raise `RequestError`, which exposes `status` and `code`. The mapper uses HTTP status and Google's structured error code. It does not copy the response body into the message.

## Configuration

```ruby
RecordingStudioGoogleDrive.configure do |config|
  config.page_size = 25
end
```

Default page size is 25.

## Later wiring

A later phase registers this gem as an upload source. Another phase places it in a Plugins directory. Those changes are out of this gem's 0.1.0.

## Dummy app

`test/dummy/` is a host that boots Recording Studio so the engine loads. Sign in at `/users/sign_in` with `admin@admin.com` / `Password`. Dummy credentials use the shared RecordingStudio development master key. Set `RAILS_MASTER_KEY` or `test/dummy/config/master.key`. Do not mint a new key.

## Development

Ruby 3.3.12. Rails 8.1. Recording Studio `~> 4.2` (dummy GitHub tag `v4.7.0`).

```bash
bundle install
BUNDLE_GEMFILE=test/dummy/Gemfile bundle install
bundle exec rake test:all
```
