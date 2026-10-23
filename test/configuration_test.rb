# frozen_string_literal: true

require "test_helper"

class ConfigurationTest < Minitest::Test
  def setup
    @configuration = RecordingStudioGoogleDrive::Configuration.new
  end

  def test_merge_updates_known_attributes
    @configuration.merge!(page_size: 40)

    assert_equal 40, @configuration.page_size
  end

  def test_merge_raises_on_unknown_keys
    error = assert_raises(ArgumentError) { @configuration.merge!(unknown_key: "ignored", page_size: 7) }

    assert_includes error.message, "unknown_key"
    assert_equal 25, @configuration.page_size
  end

  def test_merge_raises_on_non_hash
    original = @configuration.to_h

    error = assert_raises(ArgumentError) { @configuration.merge!(nil) }

    assert_includes error.message, "hash"
    assert_equal original, @configuration.to_h
  end

  def test_initialize_defaults_page_size
    assert_equal 25, @configuration.page_size
    assert_instance_of RecordingStudio::Hooks, @configuration.hooks
  end

  def test_merge_accepts_string_keys
    @configuration.merge!("page_size" => 12)

    assert_equal 12, @configuration.page_size
  end

  def test_configure_without_block_is_safe
    RecordingStudioGoogleDrive.configure

    assert_kind_of RecordingStudioGoogleDrive::Configuration, RecordingStudioGoogleDrive.configuration
  end

  def test_template_knobs_are_gone
    refute_respond_to @configuration, :api_key
    refute_respond_to @configuration, :enable_feature_x
    refute_respond_to @configuration, :timeout
  end

  def test_attachable_defaults_are_off_and_unconfigured
    attachable = @configuration.attachable

    refute_predicate attachable, :enabled?
    refute_predicate attachable, :picker_configured?
    assert_equal 25, attachable.page_size
    assert_equal ["https://www.googleapis.com/auth/drive.readonly"],
                 RecordingStudioGoogleDrive::AttachableConfiguration::DEFAULT_SCOPES
  end

  def test_merge_updates_nested_attachable_settings
    @configuration.merge!(
      attachable: { enabled: true, api_key: "picker-key", app_id: "123456", page_size: 10 }
    )
    attachable = @configuration.attachable

    assert_predicate attachable, :enabled?
    assert_predicate attachable, :picker_configured?
    assert_equal "picker-key", attachable.api_key
    assert_equal "123456", attachable.app_id
    assert_equal 10, attachable.page_size
  end

  def test_attachable_inspect_redacts_picker_secrets
    @configuration.attachable.api_key = "super-secret-picker-key"
    @configuration.attachable.app_id = "super-secret-app-id"

    refute_includes @configuration.attachable.inspect, "super-secret-picker-key"
    refute_includes @configuration.attachable.inspect, "super-secret-app-id"
    assert_includes @configuration.attachable.inspect, "api_key=[FILTERED]"
    assert_includes @configuration.attachable.inspect, "app_id=[FILTERED]"
  end

  def test_inspect_and_to_s_redact_client_secret
    secret = "dummy-fake-drive-secret"
    @configuration.client_secret = secret

    refute_includes @configuration.inspect, secret
    refute_includes @configuration.to_s, secret
    assert_includes @configuration.inspect, "client_secret=[FILTERED]"
    assert_includes @configuration.to_s, "client_secret=[FILTERED]"
  end
end
