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
