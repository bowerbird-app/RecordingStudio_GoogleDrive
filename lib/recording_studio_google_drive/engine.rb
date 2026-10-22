# frozen_string_literal: true

module RecordingStudioGoogleDrive
  class Engine < ::Rails::Engine
    isolate_namespace RecordingStudioGoogleDrive

    initializer "recording_studio_google_drive.before_initialize",
                before: "recording_studio_google_drive.load_config" do |_app|
      RecordingStudioGoogleDrive.configuration.hooks.run(:before_initialize, self)
    end

    initializer "recording_studio_google_drive.load_config" do |app|
      if File.exist?(app.root.join("config/recording_studio_google_drive.yml"))
        RecordingStudioGoogleDrive.configuration.merge!(app.config_for(:recording_studio_google_drive))
      end

      xcfg = app.config.x.recording_studio_google_drive
      RecordingStudioGoogleDrive.configuration.merge!(xcfg) unless xcfg.nil?

      RecordingStudioGoogleDrive.configuration.hooks.run(
        :on_configuration,
        RecordingStudioGoogleDrive.configuration
      )
    end

    initializer "recording_studio_google_drive.after_initialize",
                after: "recording_studio_google_drive.load_config" do |_app|
      RecordingStudioGoogleDrive.configuration.hooks.run(:after_initialize, self)
    end

    initializer "recording_studio_google_drive.register_oauth_provider",
                after: :load_config_initializers do
      RecordingStudioGoogleDrive.register_oauth_provider!
    end
  end
end
