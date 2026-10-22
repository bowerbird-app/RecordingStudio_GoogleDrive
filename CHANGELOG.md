# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [0.1.0] - 2026-10-22

### Added
- `RecordingStudioGoogleDrive::Client` for Drive list, search, metadata, download, and upload.
- `AccessToken.new(provider)` read with `#to_s`. Callables win over `#access_token`. A raw String raises `ArgumentError`. A blank token raises `ReconnectRequired`.
- `Page` with `entries`, `next_cursor`, and `more?`. Pass `cursor:` for the next page.
- `DownloadedFile` with `body`, `filename`, and `content_type`.
- `Error`, `ReconnectRequired`, and `RequestError` (`status` and `code` may be nil). HTTP 401 and `invalid_grant` map to `ReconnectRequired`.
- `RecordingStudioGoogleDrive.configure` returns the configuration. Default page size is 25.

### Upgrade notes
- This is the first release of `recording_studio_google_drive`. Add the gem, then build a client with a token provider. Do not add Oauth as a dependency until that gem is released.

[0.1.0]: https://github.com/bowerbird-app/RecordingStudio_GoogleDrive/releases/tag/v0.1.0
