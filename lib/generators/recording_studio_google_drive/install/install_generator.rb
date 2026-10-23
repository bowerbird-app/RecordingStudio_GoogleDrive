# frozen_string_literal: true

require "rails/generators"

module RecordingStudioGoogleDrive
  module Generators
    class InstallGenerator < Rails::Generators::Base
      source_root File.expand_path("templates", __dir__)

      desc "Installs RecordingStudioGoogleDrive configuration into your application"

      def copy_initializer
        template "recording_studio_google_drive_initializer.rb", "config/initializers/recording_studio_google_drive.rb"
      end

      def pin_attachable_launcher
        importmap_path = "config/importmap.rb"
        return unless File.exist?(importmap_path)

        contents = File.read(importmap_path)
        unless contents.include?("recording_studio_attachable/provider_launchers")
          append_to_file importmap_path, <<~RUBY

            pin "recording_studio_attachable/provider_launchers",
              to: "controllers/recording_studio_attachable/provider_launchers.js"
          RUBY
        end
        return if contents.include?("recording_studio_google_drive/google_drive_picker_launcher")

        append_to_file importmap_path, <<~RUBY

          pin "recording_studio_google_drive/google_drive_picker_launcher",
            to: "recording_studio_google_drive/google_drive_picker_launcher.js"
        RUBY
      end

      def add_yaml_config
        prompt = "Would you like to add `config/recording_studio_google_drive.yml` " \
                 "for environment-specific settings? [y/N]"
        return unless yes?(prompt)

        template "recording_studio_google_drive.yml", "config/recording_studio_google_drive.yml"
      end

      def show_readme
        readme "INSTALL.md" if behavior == :invoke
      end
    end
  end
end
