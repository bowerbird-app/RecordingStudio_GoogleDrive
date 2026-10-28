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
    refute attrs.key?(:kind)
  end

  def test_register_oauth_provider_skips_when_credentials_are_blank
    RecordingStudioGoogleDrive.configuration.client_id = nil
    RecordingStudioGoogleDrive.configuration.client_secret = nil
    registered = false

    Rails.stub(:application, blank_rails_credentials_app) do
      RecordingStudioOauth.stub(:register_outbound_provider, ->(**) { registered = true }) do
        RecordingStudioGoogleDrive.register_oauth_provider
      end
    end

    refute registered
  end

  def test_register_oauth_provider_registers_kind_root
    RecordingStudioGoogleDrive.configuration.client_id = "drive-client"
    RecordingStudioGoogleDrive.configuration.client_secret = "drive-secret"
    captured = nil
    RecordingStudioOauth.stub(:register_outbound_provider, ->(**attrs) { captured = attrs }) do
      RecordingStudioGoogleDrive.register_oauth_provider
    end

    assert_equal :google_drive, captured[:key]
    assert_equal :root, captured[:kind]
    assert_equal "drive-client", captured[:client_id]
    assert_equal "drive-secret", captured[:client_secret]
    assert_equal true, captured[:refresh]
  end

  def test_register_oauth_provider_raises_when_only_one_credential_is_blank
    [
      ["drive-client", nil, "client_secret is required"],
      [nil, "drive-secret", "client_id is required"]
    ].each do |client_id, client_secret, message|
      RecordingStudioGoogleDrive.configuration.client_id = client_id
      RecordingStudioGoogleDrive.configuration.client_secret = client_secret
      registered = 0
      Rails.stub(:application, blank_rails_credentials_app) do
        error = assert_raises(ArgumentError) do
          RecordingStudioOauth.stub(
            :register_outbound_provider,
            lambda { |**|
              registered += 1
              raise ArgumentError, message
            }
          ) do
            RecordingStudioGoogleDrive.register_oauth_provider
          end
        end

        assert_equal message, error.message
        assert_equal 1, registered
      end
    end
  end

  def test_register_oauth_provider_does_not_swallow_oauth_errors
    RecordingStudioGoogleDrive.configuration.client_id = "drive-client"
    RecordingStudioGoogleDrive.configuration.client_secret = "drive-secret"

    error = assert_raises(ArgumentError) do
      RecordingStudioOauth.stub(
        :register_outbound_provider,
        ->(**) { raise ArgumentError, "authorize_url is required" }
      ) do
        RecordingStudioGoogleDrive.register_oauth_provider
      end
    end

    assert_equal "authorize_url is required", error.message
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

  def test_register_oauth_provider_runs_when_credentials_are_in_rails
    RecordingStudioGoogleDrive.configuration.client_id = nil
    RecordingStudioGoogleDrive.configuration.client_secret = nil
    app = Object.new
    app.define_singleton_method(:credentials) do
      {
        recording_studio_oauth: {
          outbound: { google_drive: { client_id: "from-rails", client_secret: "from-rails-secret" } }
        }
      }
    end
    app.define_singleton_method(:respond_to?) { |name, *| name == :credentials || super(name) }

    captured = nil
    Rails.stub(:application, app) do
      RecordingStudioOauth.stub(:register_outbound_provider, ->(**attrs) { captured = attrs }) do
        RecordingStudioGoogleDrive.register_oauth_provider
      end
    end

    assert_equal :google_drive, captured[:key]
    assert_equal :root, captured[:kind]
  end

  def test_engine_does_not_register_the_oauth_provider
    names = RecordingStudioGoogleDrive::Engine.initializers.map(&:name)
    source = File.read(File.expand_path("../lib/recording_studio_google_drive/engine.rb", __dir__))

    refute_includes names, "recording_studio_google_drive.register_oauth_provider"
    refute_includes source, "register_oauth_provider"
    refute_includes source, "register_outbound_provider"
  end

  def test_gemspec_pins_oauth_below_1_0
    gemspec = File.read(File.expand_path("../recording_studio_google_drive.gemspec", __dir__))
    gemfile = File.read(File.expand_path("../Gemfile", __dir__))
    dummy_gemfile = File.read(File.expand_path("dummy/Gemfile", __dir__))

    assert_includes gemspec, 'spec.add_dependency "recording_studio_oauth", ">= 0.17.0", "< 1.0"'
    assert_includes gemfile, 'github: "bowerbird-app/RecordingStudio_Oauth", tag: "v0.20.0"'
    assert_includes dummy_gemfile, 'github: "bowerbird-app/RecordingStudio_Oauth", tag: "v0.20.0"'
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

  def blank_rails_credentials_app
    app = Object.new
    app.define_singleton_method(:credentials) { {} }
    app.define_singleton_method(:respond_to?) { |name, *| name == :credentials || super(name) }
    app
  end
end
