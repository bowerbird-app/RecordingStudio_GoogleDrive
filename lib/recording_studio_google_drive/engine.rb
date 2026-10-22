# frozen_string_literal: true

module RecordingStudioGoogleDrive
  class Engine < ::Rails::Engine
    isolate_namespace RecordingStudioGoogleDrive

    initializer "recording_studio_google_drive.before_initialize",
                before: "recording_studio_google_drive.load_config" do |_app|
      RecordingStudioGoogleDrive.configuration.hooks.run(:before_initialize, self)
    end

    initializer "recording_studio_google_drive.load_config" do |app|
      if app.respond_to?(:config_for) && File.exist?(app.root.join("config/recording_studio_google_drive.yml"))
        yaml = app.config_for(:recording_studio_google_drive)
        RecordingStudioGoogleDrive.configuration.merge!(yaml) if yaml.respond_to?(:each)
      end

      if app.config.respond_to?(:x) && app.config.x.respond_to?(:recording_studio_google_drive)
        xcfg = app.config.x.recording_studio_google_drive
        if xcfg.respond_to?(:to_h)
          RecordingStudioGoogleDrive.configuration.merge!(xcfg.to_h)
        elsif xcfg.respond_to?(:each_pair)
          hash = {}
          xcfg.each_pair { |key, value| hash[key] = value }
          RecordingStudioGoogleDrive.configuration.merge!(hash)
        end
      end

      RecordingStudioGoogleDrive.configuration.hooks.run(
        :on_configuration,
        RecordingStudioGoogleDrive.configuration
      )
    end

    initializer "recording_studio_google_drive.after_initialize",
                after: "recording_studio_google_drive.load_config" do |_app|
      RecordingStudioGoogleDrive.configuration.hooks.run(:after_initialize, self)
    end
  end
end
