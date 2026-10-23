# frozen_string_literal: true

require "test_helper"
require "recording_studio_attachable"
require "recording_studio_google_drive/attachable"

class AttachableRegistrationTest < Minitest::Test
  def test_load_attachable_addon_registers_routes_and_provider
    original = RecordingStudioGoogleDrive.configuration.attachable.enabled
    RecordingStudioGoogleDrive.configuration.attachable.enabled = true
    routes = nil
    provider = nil

    RecordingStudioAttachable.stub(:register_adapter_routes, lambda { |key, &block|
      routes = [key, block]
    }) do
      RecordingStudioAttachable.stub(:register_upload_provider, lambda { |key, **options|
        provider = [key, options]
      }) do
        RecordingStudioGoogleDrive.load_attachable_addon!
      end
    end

    assert_equal :google_drive, routes.first
    assert_equal :google_drive, provider.first
    options = provider.last
    assert_equal :client_picker, options[:strategy]
    assert_equal "google_drive", options[:launcher]
    assert_equal RecordingStudioGoogleDrive::Attachable::LAUNCHER_MODULE, options[:launcher_module]
    assert_equal %w[id resource_key], options[:allowed_payload_keys]
    assert_respond_to options[:connect], :call
    assert_respond_to options[:reconnect_error], :call
    assert_equal true, options[:reconnect_error].call(RecordingStudioGoogleDrive::ReconnectRequired.new("x"))
    assert_equal false, options[:reconnect_error].call(StandardError.new("x"))
    assert_keyword_only options[:connect]
    assert_keyword_only options[:remote_importer]
    assert_equal %i[recording context], keyword_names(options[:connect])
    assert_equal %i[parent_recording attachments actor impersonator context],
                 keyword_names(options[:remote_importer])
  ensure
    RecordingStudioGoogleDrive.configuration.attachable.enabled = original
  end

  def test_attachable_version_rejects_versions_below_minimum
    error = assert_raises(RuntimeError) do
      RecordingStudioGoogleDrive.assert_attachable_version!("0.20.9")
    end

    assert_includes error.message, "0.21.0"
    assert_includes error.message, "0.20.9"
  end

  def test_attachable_version_accepts_the_minimum
    RecordingStudioGoogleDrive.assert_attachable_version!("0.21.0")
  end

  def test_engine_loads_the_attachable_addon_after_host_initializers
    names = RecordingStudioGoogleDrive::Engine.initializers.map(&:name)

    assert_includes names, "recording_studio_google_drive.load_attachable_addon"
    refute_includes names, "recording_studio_google_drive.register_attachable_upload_provider"
  end

  def test_engine_initializer_registers_adapter_routes_and_upload_provider
    routes = false
    provider = false
    RecordingStudioGoogleDrive::Attachable.stub(:register_adapter_routes!, -> { routes = true }) do
      RecordingStudioGoogleDrive::Attachable.stub(:register_upload_provider!, -> { provider = true }) do
        find_attachable_initializer.block.call(Object.new)
      end
    end

    assert routes
    assert provider
  end

  def test_register_upload_provider_is_a_no_op_when_disabled
    original = RecordingStudioGoogleDrive.configuration.attachable.enabled
    RecordingStudioGoogleDrive.configuration.attachable.enabled = false
    captured = []
    RecordingStudioAttachable.stub(:register_upload_provider, ->(*args, **kwargs) { captured << [args, kwargs] }) do
      RecordingStudioGoogleDrive::Attachable.register_upload_provider!
    end

    assert_empty captured
  ensure
    RecordingStudioGoogleDrive.configuration.attachable.enabled = original
  end

  def test_controllers_inherit_provider_controller
    application = File.read(
      File.expand_path(
        "../lib/recording_studio_google_drive/attachable/app/controllers/" \
        "recording_studio_google_drive/attachable/application_controller.rb",
        __dir__
      )
    )

    assert_includes application, "RecordingStudioAttachable::ProviderController"
    assert_includes application, "self.upload_provider_key = :google_drive"
  end

  private

  def assert_keyword_only(callable)
    types = callable.parameters.map(&:first)
    refute_includes types, :req
    refute_includes types, :opt
    refute_includes types, :rest
    assert types.intersect?(%i[key keyreq keyrest])
  end

  def keyword_names(callable)
    callable.parameters.filter_map { |type, name| name if %i[key keyreq].include?(type) }
  end

  def find_attachable_initializer
    RecordingStudioGoogleDrive::Engine.initializers.find do |initializer|
      initializer.name == "recording_studio_google_drive.load_attachable_addon"
    end
  end
end
