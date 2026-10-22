# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [0.1.0] - 2026-10-22

### Added
- `RecordingStudioGoogleDrive::Client` for Drive list, metadata, download, and upload.
- Token input through a callable or an object that responds to `access_token`.
- `ReconnectRequired` for expired, revoked, and insufficient-scope tokens.

### Upgrade notes
- This is the first release of `recording_studio_google_drive`. Add the gem, then build a client with a token provider. Do not add Oauth as a dependency until that gem is released.

[0.1.0]: https://github.com/bowerbird-app/RecordingStudio_GoogleDrive/releases/tag/v0.1.0
