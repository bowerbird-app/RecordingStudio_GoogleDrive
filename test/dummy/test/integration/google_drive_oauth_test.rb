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
    grant_workspace_access!(@root_recording)
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

    connection = workspace_drive_connection!
    assert_equal "active", connection.status
    refute_nil connection.access_token
    refute_includes connection.inspect, connection.access_token
    assert_nil session[:access_token]
    assert_nil session["refresh_token"]

    switch_to_workspace_root!
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
    live = workspace_drive_connection!
    assert_equal "active", live.status
    refute_equal connection.id, live.id

    live.update!(status: "needs_reconnect")
    switch_to_workspace_root!
    get "/"
    assert_includes response.body, "Reconnect"
  end

  test "expired token refreshes through oauth before the client reads it" do
    follow_connect!
    connection = workspace_drive_connection!
    old_token = connection.access_token
    connection.update!(expires_at: 1.minute.ago)

    refreshed = RecordingStudioGoogleDrive::TokenStore.new(root: @root_recording, actor: @user).call
    refute_equal old_token, refreshed
    refute_includes refreshed, " "
  end

  test "picker_access_token returns the live oauth token" do
    follow_connect!
    connection = workspace_drive_connection!

    token = RecordingStudioGoogleDrive.picker_access_token(root: @root_recording, actor: @user)

    assert_equal connection.access_token, token
    refute_includes token, FakeOauth::FAIL_REFRESH
  end

  test "picker_access_token raises reconnect required when there is no connection" do
    error = assert_raises(RecordingStudioGoogleDrive::ReconnectRequired) do
      RecordingStudioGoogleDrive.picker_access_token(root: @root_recording, actor: @user)
    end
    assert_equal "Google Drive needs connecting again", error.message
  end

  test "picker_access_token raises reconnect required when the connection needs reconnect" do
    follow_connect!
    connection = workspace_drive_connection!
    connection.update!(status: "needs_reconnect")

    error = assert_raises(RecordingStudioGoogleDrive::ReconnectRequired) do
      RecordingStudioGoogleDrive.picker_access_token(root: @root_recording, actor: @user)
    end
    assert_kind_of RecordingStudioGoogleDrive::ReconnectRequired, error
    refute_includes error.message, FakeOauth::FAIL_REFRESH
  end

  test "refresh failure raises reconnect required" do
    follow_connect!
    connection = workspace_drive_connection!
    connection.update!(refresh_token: FakeOauth::FAIL_REFRESH, expires_at: 1.minute.ago)

    error = assert_raises(RecordingStudioGoogleDrive::ReconnectRequired) do
      RecordingStudioGoogleDrive::TokenStore.new(root: @root_recording, actor: @user).call
    end
    assert_equal "needs_reconnect", connection.reload.status
    refute_includes error.message, FakeOauth::FAIL_REFRESH
    refute_includes error.message, connection.refresh_token.to_s
  end

  test "google_drive provider is registered with fake local endpoints" do
    post recording_studio_oauth.outbound_connect_path(provider: "google_drive"), params: {
      owner: "root",
      root_recording_id: @root_recording.id,
      return_to: "/"
    }
    assert_response :redirect

    location = URI.parse(response.redirect_url)
    query = Rack::Utils.parse_query(location.query)

    assert_equal "/fake_oauth/authorize", location.path
    assert_equal FakeOauth::CLIENT_ID, query["client_id"]
    assert_equal "offline", query["access_type"]
    assert_equal "consent", query["prompt"]
  end

  test "host register_oauth_provider is idempotent and lists google drive as a root provider" do
    listed = RecordingStudioOauth.outbound_providers.find { |entry| entry[:key].to_s == "google_drive" }

    assert_equal({ key: "google_drive", kind: :root }, listed)

    RecordingStudioGoogleDrive.register_oauth_provider
    listed_again = RecordingStudioOauth.outbound_providers.select { |entry| entry[:key].to_s == "google_drive" }

    assert_equal 1, listed_again.size
    assert_equal({ key: "google_drive", kind: :root }, listed_again.first)
  end

  private

  def workspace_drive_connection!
    RecordingStudioOauth::OutboundConnection.live.find_by!(
      provider_key: "google_drive",
      root_recording_id: @root_recording.id
    )
  end

  def grant_workspace_access!(root, actor: @user, role: :admin)
    result = RecordingStudioAccessible.bootstrap_owner_access!(
      recording: root,
      actor: actor
    )
    raise result.error if result.failure?
    return if role.to_s == "admin"

    grant = RecordingStudioAccessible.grant_access(
      recording: root,
      actor: actor,
      role: role,
      manager_actor: actor
    )
    raise grant.error if grant.failure?
  end

  def switch_to_workspace_root!
    patch "/recording_studio_root_switchable/v1/root_switch", params: {
      scope: "all_workspaces",
      root_switch: {
        root_recording_id: @root_recording.id,
        return_to: "/"
      }
    }
  end

  def follow_connect!
    post recording_studio_oauth.outbound_connect_path(provider: "google_drive"), params: {
      owner: "root",
      root_recording_id: @root_recording.id,
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
