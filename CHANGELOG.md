# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/), and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

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

[0.1.0]: https://github.com/bowerbird-app/RecordingStudio_GoogleDrive/releases/tag/v0.1.0
