# frozen_string_literal: true

require "test_helper"
require "devise/test/integration_helpers"
require "uri"

class GoogleDriveOauthTest < ActionDispatch::IntegrationTest
  include Devise::Test::IntegrationHelpers

  setup do
    FakeOauth.reset!
    @user = User.create!(
      email: "drive-#{SecureRandom.hex(4)}@example.com",
      password: "Password123!",
      password_confirmation: "Password123!"
    )
    @workspace = Workspace.create!(name: "Drive Workspace #{SecureRandom.hex(4)}")
    @root_recording = RecordingStudio.root_recording_for(@workspace)
    sign_in @user
  end

  teardown do
    Current.actor = nil if defined?(Current)
    FakeOauth.reset!
  end

  test "home shows connect when there is no Google Drive connection" do
    get "/"

    assert_response :success
    assert_includes response.body, "Connect Google Drive"
    assert_includes response.body, "Not connected"
    refute_includes response.body, "fake-access-"
  end

  test "connect disconnect and reconnect for Google Drive" do
    follow_connect!

    connection = RecordingStudioOauth::OutboundConnection.find_by!(
      provider_key: "google_drive",
      owner_actor: @user
    )
    assert_equal "active", connection.status
    refute_nil connection.access_token
    refute_includes connection.inspect, connection.access_token
    assert_nil session[:access_token]
    assert_nil session["refresh_token"]

    get "/"
    assert_response :success
    assert_includes response.body, "Disconnect"
    assert_includes response.body, "Connected"
    refute_includes response.body, connection.access_token

    found = RecordingStudioOauth.connection_for(
      provider: :google_drive,
      root: @root_recording,
      actor: @user
    )
    assert_equal connection.id, found.id
    assert_equal connection.access_token, RecordingStudioGoogleDrive::TokenStore.new(
      root: @root_recording,
      actor: @user
    ).call

    delete recording_studio_oauth.outbound_connection_path(connection), params: { return_to: "/" }
    assert_response :redirect
    assert_equal "revoked", connection.reload.status
    assert_nil connection.access_token
    assert_raises(RecordingStudioGoogleDrive::ReconnectRequired) do
      RecordingStudioGoogleDrive::TokenStore.new(root: @root_recording, actor: @user).call
    end

    get "/"
    assert_includes response.body, "Connect Google Drive"

    follow_connect!
    live = RecordingStudioOauth::OutboundConnection.live.find_by!(owner_actor: @user)
    assert_equal "active", live.status
    refute_equal connection.id, live.id

    live.update!(status: "needs_reconnect")
    get "/"
    assert_includes response.body, "Reconnect"
  end

  test "expired token refreshes through oauth before the client reads it" do
    follow_connect!
    connection = RecordingStudioOauth::OutboundConnection.find_by!(owner_actor: @user)
    old_token = connection.access_token
    connection.update!(expires_at: 1.minute.ago)

    refreshed = RecordingStudioGoogleDrive::TokenStore.new(root: @root_recording, actor: @user).call
    refute_equal old_token, refreshed
    refute_includes refreshed, " "
  end

  test "refresh failure raises reconnect required" do
    follow_connect!
    connection = RecordingStudioOauth::OutboundConnection.find_by!(owner_actor: @user)
    connection.update!(refresh_token: FakeOauth::FAIL_REFRESH, expires_at: 1.minute.ago)

    error = assert_raises(RecordingStudioGoogleDrive::ReconnectRequired) do
      RecordingStudioGoogleDrive::TokenStore.new(root: @root_recording, actor: @user).call
    end
    assert_equal "needs_reconnect", connection.reload.status
    refute_includes error.message, FakeOauth::FAIL_REFRESH
    refute_includes error.message, connection.refresh_token.to_s
  end

  test "google_drive provider is registered with fake local endpoints" do
    provider = RecordingStudioOauth::Outbound.provider(:google_drive)

    assert_equal "google_drive", provider.key
    assert_equal "/fake_oauth/authorize", provider.authorize_url
    assert_equal "/fake_oauth/token", provider.token_url
    assert_equal "/fake_oauth/revoke", provider.revoke_url
    assert_equal true, provider.refresh?
  end

  private

  def follow_connect!
    post recording_studio_oauth.outbound_connect_path(provider: "google_drive"), params: {
      owner: "user",
      return_to: "/"
    }
    assert_response :redirect
    follow_redirect!
    assert_response :redirect
    follow_redirect!
    assert_response :redirect
    follow_redirect!
  end
end
