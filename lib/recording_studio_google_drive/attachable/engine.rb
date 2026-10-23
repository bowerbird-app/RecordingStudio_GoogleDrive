# frozen_string_literal: true

require "pathname"

module RecordingStudioGoogleDrive
  module Attachable
    class Engine < ::Rails::Engine
      isolate_namespace RecordingStudioGoogleDrive::Attachable
      engine_name "google_drive"
      config.root = Pathname.new(File.expand_path(".", __dir__))
    end
  end
end
