# frozen_string_literal: true

require "test_helper"

class AttachableRegistrationTest < Minitest::Test
  def test_attachable_addon_uses_public_hooks_only
    source = File.read(File.expand_path("../lib/recording_studio_google_drive/attachable.rb", __dir__))

    assert_includes source, "ActiveSupport.on_load(:recording_studio_attachable)"
    assert_includes source, "register_adapter_routes(:google_drive)"
    assert_includes source, 'at: "/google_drive", as: :google_drive'
    assert_includes source, "register_upload_provider"
    assert_includes source, "connect:"
    assert_includes source, "reconnect_error:"
    refute_includes source, "send("
    refute_includes source, "instance_variable_get"
    refute_includes source, "class_eval"
    refute_includes source, "alias_method"
    refute_includes source, "prepend"
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
    assert_includes source, "csrfToken"
    assert_includes source, "if (!gesture)"
    assert_includes source, "return providerNeedsAuth(bootstrap)"
    refute_includes source, "bootstrap?.connect"
    refute_includes source, "function loadScript"
    refute_includes source, "function csrfToken"
    refute_includes source, "function providerNeedsAuth"
  end

  def test_engine_registers_the_attachable_upload_provider_after_host_initializers
    names = RecordingStudioGoogleDrive::Engine.initializers.map(&:name)

    assert_includes names, "recording_studio_google_drive.register_attachable_upload_provider"
  end

  def test_register_upload_provider_is_a_no_op_when_disabled
    require "recording_studio_attachable"
    require "recording_studio_google_drive/attachable"

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

  def test_register_upload_provider_passes_public_connect_hooks_when_enabled
    require "recording_studio_attachable"
    require "recording_studio_google_drive/attachable"

    original = RecordingStudioGoogleDrive.configuration.attachable.enabled
    RecordingStudioGoogleDrive.configuration.attachable.enabled = true
    captured = nil
    RecordingStudioAttachable.stub(:register_upload_provider, lambda { |key, **options|
      captured = [key, options]
    }) do
      RecordingStudioGoogleDrive::Attachable.register_upload_provider!
    end

    key, options = captured
    assert_equal :google_drive, key
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
  end

  private

  def assert_keyword_only(callable)
    types = callable.parameters.map(&:first)
    refute_includes types, :req
    refute_includes types, :opt
    assert types.intersect?(%i[key keyreq keyrest])
  end
end
