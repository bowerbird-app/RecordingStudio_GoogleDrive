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
end
