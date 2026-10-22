# frozen_string_literal: true

require "fileutils"
require "pathname"
require "tmpdir"
require "test_helper"

class EngineTest < Minitest::Test
  def setup
    @original_page_size = RecordingStudioGoogleDrive.configuration.page_size
  end

  def teardown
    RecordingStudioGoogleDrive.configuration.page_size = @original_page_size
    RecordingStudioGoogleDrive.configuration.hooks.clear!
  end

  def test_before_and_after_initialize_initializers_run_hooks
    before_called = false
    after_called = false

    RecordingStudioGoogleDrive.configuration.hooks.before_initialize { |_engine| before_called = true }
    RecordingStudioGoogleDrive.configuration.hooks.after_initialize { |_engine| after_called = true }

    find_initializer("recording_studio_google_drive.before_initialize").block.call(Object.new)
    find_initializer("recording_studio_google_drive.after_initialize").block.call(Object.new)

    assert before_called
    assert after_called
  end

  def test_load_config_merges_yaml_and_x_config
    hook_called = false
    hook_payload = nil
    RecordingStudioGoogleDrive.configuration.hooks.on_configuration do |cfg|
      hook_called = true
      hook_payload = cfg
    end

    root = Pathname.new(Dir.mktmpdir)
    FileUtils.mkdir_p(root.join("config"))
    File.write(root.join("config/recording_studio_google_drive.yml"), "page_size: 12\n")

    xcfg = Struct.new(:recording_studio_google_drive).new({ page_size: 40 })
    app_config = Struct.new(:x).new(xcfg)
    app = Struct.new(:config, :root) do
      def config_for(_name)
        { page_size: 12 }
      end
    end.new(app_config, root)

    find_initializer("recording_studio_google_drive.load_config").block.call(app)

    assert hook_called
    assert_equal RecordingStudioGoogleDrive.configuration, hook_payload
    assert_equal 40, RecordingStudioGoogleDrive.configuration.page_size
  ensure
    FileUtils.remove_entry(app.root) if defined?(app) && app&.root && File.directory?(app.root)
  end

  def test_load_config_is_noop_without_config_sources
    app = Struct.new(:config, :root).new(Object.new, Pathname.new("/tmp/missing-google-drive-config"))

    find_initializer("recording_studio_google_drive.load_config").block.call(app)

    assert_equal 25, RecordingStudioGoogleDrive.configuration.page_size
  end

  def test_engine_does_not_class_eval_host_models
    source = File.read(File.expand_path("../lib/recording_studio_google_drive/engine.rb", __dir__))

    refute_includes source, "class_eval"
    refute_includes source, "instance_variable_get"
    refute_includes source, "apply_model_extensions"
  end

  private

  def find_initializer(name)
    RecordingStudioGoogleDrive::Engine.initializers.find { |initializer| initializer.name == name }
  end
end
