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

  def test_load_attachable_addon_rejects_older_attachable
    original = RecordingStudioAttachable::VERSION
    silence_warnings do
      RecordingStudioAttachable.send(:remove_const, :VERSION)
      RecordingStudioAttachable.const_set(:VERSION, "0.20.9")
    end

    error = assert_raises(RuntimeError) { RecordingStudioGoogleDrive.load_attachable_addon! }

    assert_includes error.message, "0.21.0"
    assert_includes error.message, "0.20.9"
  ensure
    silence_warnings do
      RecordingStudioAttachable.send(:remove_const, :VERSION)
      RecordingStudioAttachable.const_set(:VERSION, original)
    end
  end

  def test_picker_launcher_imports_attachable_helpers
    source = File.read(
      File.expand_path("../app/javascript/recording_studio_google_drive/google_drive_picker_launcher.js", __dir__)
    )

    assert_includes source, 'from "recording_studio_attachable/provider_launchers"'
    assert_includes source, "loadScript"
    assert_includes source, "createBootstrapCache"
    assert_includes source, "providerNeedsAuth"
    assert_includes source, "openProviderAuth"
    assert_includes source, "if (!gesture)"
    refute_includes source, "csrfToken"
    refute_includes source, "bootstrap?.connect"
    refute_includes source, "function loadScript"
    refute_includes source, "function csrfToken"
    refute_includes source, "function providerNeedsAuth"
    refute_includes source, "function driveNeedsAuth"
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

  def test_browser_partial_locals_use_generic_content_type_and_folder_rows
    support = File.read(
      File.expand_path("../lib/recording_studio_google_drive/attachable/browser_row.rb", __dir__)
    )
    view = File.read(
      File.expand_path(
        "../lib/recording_studio_google_drive/attachable/app/views/" \
        "recording_studio_google_drive/attachable/imports/index.html.erb",
        __dir__
      )
    )

    refute_includes support, "mimeType"
    assert_includes support, "kind: :folder"
    assert_includes view, "current_path: @current_path"
    assert_includes view, "parent_url: @parent_url"
    assert_includes view, "path: @path"
    assert_includes view, "flow_params: upload_flow_params"
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
