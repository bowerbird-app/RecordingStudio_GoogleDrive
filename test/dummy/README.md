# Dummy App

This Rails app exists to validate the Recording Studio Google Drive addon in a real host application.

## What It Covers

- Devise authentication with a seeded admin user
- `Current.actor` wiring for Recording Studio events
- Root workspace plus seeded folder and page recordables
- Recording Studio default layout, FlatPack assets, and Tailwind source scanning
- Mounted `RecordingStudio::Engine` route behavior inside a host app
- Oauth outbound Connect, Disconnect, and Reconnect for Google Drive against a local fake provider
- Attachable upload page with this gem's Google Drive add-on
- Dummy-only `/docs/*` pages for gem-specific onboarding

## Quick Start

```bash
cd test/dummy
bundle install
bin/rails db:setup
bin/dev
```

Run the commands above from the dummy app directory, not the repository root.

Then open the app and sign in with:

- Email: `admin@admin.com`
- Password: `Password`

Without Google secrets, dummy registers `:google_drive` against `/fake_oauth/*`. For a real Drive import, set `attachable.google_drive.*` or `google_drive.*` in Rails credentials, or `GOOGLE_DRIVE_CLIENT_ID`, `GOOGLE_DRIVE_CLIENT_SECRET`, `GOOGLE_DRIVE_API_KEY`, and `GOOGLE_DRIVE_APP_ID`. `RAILS_DEVELOPMENT_HOSTS` adds allowed hosts.

## Useful Routes

- `/` - Connect, Disconnect, and Reconnect Google Drive, plus a link to the seeded page upload
- `/recording_studio_attachable/recordings/:id/attachments/upload` - Attachable upload page (seeds print the Getting Started page id)
- `/recording_studio` - redirects to `/` while the mounted Recording Studio engine stays available under that prefix for non-root routes
- `/recording_studio_oauth` - Oauth engine (outbound callback lives here)
- `/users/sign_in` - Devise sign-in page
- `/docs/install`, `/docs/config` - dummy-only starter pages
- `/up` - Rails health check

## Why This App Exists

Use this app to verify the engine boots in a host. If a layout, route, asset source, or Recording Studio initializer change breaks here, fix it before a host copies the pattern.

Authenticated pages use Recording Studio's shared default layout. Devise sign-in keeps `layouts/application`. Replace dummy docs page content so it matches the gem's actual concepts.

The home page in `app/views/home/index.html.erb` should stay a minimal demo surface for the gem's core feature. Do not turn it into a wall of documentation; the dummy docs pages exist so deeper explanations can live in focused sections.
