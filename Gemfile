# frozen_string_literal: true

source "https://rubygems.org"

# Specify your gem's dependencies in recording_studio_google_drive.gemspec
gemspec

# recording_studio is not published to RubyGems; resolve the gemspec pin from GitHub.
gem "flat_pack", github: "bowerbird-app/flatpack", tag: "v0.1.213"
gem "recording_studio", github: "bowerbird-app/RecordingStudio", tag: "v4.7.0"
gem "recording_studio_accessible", github: "bowerbird-app/RecordingStudio_accessible", tag: "v0.18.0"
gem "recording_studio_admin", github: "bowerbird-app/RecordingStudio_admin", tag: "v2.2.0"
gem "recording_studio_api", github: "bowerbird-app/RecordingStudio_api", tag: "v0.14.0"
gem "recording_studio_attachable",
    github: "bowerbird-app/RecordingStudio_attachable",
    ref: "900cc3a169e26f0e4604e1acb3cbc1d81281aa87"
gem "recording_studio_cache", github: "bowerbird-app/RecordingStudio_cache", tag: "v0.5.0"
gem "recording_studio_logs", github: "bowerbird-app/RecordingStudio_logs", tag: "v0.4.1"
gem "recording_studio_metrics", github: "bowerbird-app/RecordingStudio_metrics", tag: "v0.5.0"
gem "recording_studio_oauth", github: "bowerbird-app/RecordingStudio_Oauth", tag: "v0.14.1"
gem "recording_studio_site_settings", github: "bowerbird-app/RecordingStudio_site_settings", tag: "v0.2.0"
gem "recording_studio_trashable", github: "bowerbird-app/RecordingStudio_trashable", tag: "v0.11.0", require: false

gem "devise"
gem "puma"
gem "sprockets-rails"

group :development, :test do
  gem "debug"
  gem "minitest-mock"
  gem "simplecov", require: false
  gem "webmock", require: false
end

group :development do
  gem "rubocop", require: false
  gem "rubocop-rails", require: false
end
