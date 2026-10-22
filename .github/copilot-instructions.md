# Project Guidelines

## Architecture

- This repository is the Recording Studio Google Drive library gem.
- Preserve engine namespace isolation under `RecordingStudioGoogleDrive`.
- Prefer the top-level README and the dummy app for current addon workflow.
- Keep changes small and scoped.

## Testing

- The standard root validation command is `bundle exec rake test` from the repository root.
- If a change affects dummy app boot, assets, or migrations, also validate the dummy app setup the same way CI does.
- Add focused regression tests for engine hooks, generators, Recording Studio integration points, and dummy host wiring.

## Repo Conventions

- Keep internal dependency assumptions intact unless the request explicitly asks to change private gem infrastructure.
- Update docs when public client behavior or setup steps change.
- Prefer existing generator, service, and hook patterns over introducing a parallel abstraction.
