# frozen_string_literal: true

require "test_helper"

class OauthProviderTest < Minitest::Test
  def setup
    @original = snapshot_config
  end

  def teardown
    restore_config(@original)
  end

  def test_oauth_provider_attrs_use_google_defaults
    attrs = RecordingStudioGoogleDrive.oauth_provider_attrs

    assert_equal :google_drive, attrs[:key]
    assert_equal "https://accounts.google.com/o/oauth2/v2/auth", attrs[:authorize_url]
    assert_equal "https://oauth2.googleapis.com/token", attrs[:token_url]
    assert_equal "https://oauth2.googleapis.com/revoke", attrs[:revoke_url]
    assert_equal ["https://www.googleapis.com/auth/drive"], attrs[:scopes]
    assert_equal true, attrs[:pkce]
    assert_equal true, attrs[:refresh]
    assert_equal({ "access_type" => "offline", "prompt" => "consent" }, attrs[:extra_authorize_params])
    refute attrs.key?(:client_id)
    refute attrs.key?(:client_secret)
    refute attrs.key?(:http)
  end

  def test_register_oauth_provider_uses_oauth_public_api
    captured = nil
    RecordingStudioOauth.stub(:register_outbound_provider, ->(**attrs) { captured = attrs }) do
      RecordingStudioGoogleDrive.register_oauth_provider!
    end

    assert_equal :google_drive, captured[:key]
    assert_equal true, captured[:refresh]
  end

  def test_dummy_fake_credentials_are_passed_when_configured
    RecordingStudioGoogleDrive.configure do |config|
      config.authorize_url = "/fake_oauth/authorize"
      config.token_url = "/fake_oauth/token"
      config.revoke_url = "/fake_oauth/revoke"
      config.client_id = "dummy-fake-drive"
      config.client_secret = "dummy-fake-drive-secret"
      config.http = :fake
    end

    attrs = RecordingStudioGoogleDrive.oauth_provider_attrs

    assert_equal "/fake_oauth/authorize", attrs[:authorize_url]
    assert_equal "dummy-fake-drive", attrs[:client_id]
    assert_equal :fake, attrs[:http]
  end

  def test_engine_registers_the_oauth_provider_after_host_initializers
    names = RecordingStudioGoogleDrive::Engine.initializers.map(&:name)

    assert_includes names, "recording_studio_google_drive.register_oauth_provider"
  end

  def test_gemspec_pins_oauth_below_1_0
    gemspec = File.read(File.expand_path("../recording_studio_google_drive.gemspec", __dir__))
    gemfile = File.read(File.expand_path("../Gemfile", __dir__))
    dummy_gemfile = File.read(File.expand_path("dummy/Gemfile", __dir__))

    assert_includes gemspec, 'spec.add_dependency "recording_studio_oauth", ">= 0.14.1", "< 1.0"'
    assert_includes gemfile, 'github: "bowerbird-app/RecordingStudio_Oauth", tag: "v0.14.1"'
    assert_includes dummy_gemfile, 'github: "bowerbird-app/RecordingStudio_Oauth", tag: "v0.14.1"'
  end

  private

  def snapshot_config
    config = RecordingStudioGoogleDrive.configuration
    {
      authorize_url: config.authorize_url,
      token_url: config.token_url,
      revoke_url: config.revoke_url,
      client_id: config.client_id,
      client_secret: config.client_secret,
      http: config.http
    }
  end

  def restore_config(values)
    config = RecordingStudioGoogleDrive.configuration
    values.each { |key, value| config.public_send("#{key}=", value) }
  end
end
