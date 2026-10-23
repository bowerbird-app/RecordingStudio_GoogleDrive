# frozen_string_literal: true

require "test_helper"
require "devise/test/integration_helpers"
require "uri"

class GoogleDriveAttachableTest < ActionDispatch::IntegrationTest
  include Devise::Test::IntegrationHelpers

  setup do
    FakeOauth.reset!
    @user = User.create!(
      email: "drive-attachable-#{SecureRandom.hex(4)}@example.com",
      password: "Password123!",
      password_confirmation: "Password123!"
    )
    @workspace = Workspace.create!(name: "Drive Attachable #{SecureRandom.hex(4)}")
    sign_in @user
    Current.actor = @user
    @root = RecordingStudio.root_recording_for(@workspace)
    grant_workspace_access!(@root)
    @page = Page.create!(title: "Drive page #{SecureRandom.hex(4)}")
    @recording = RecordingStudio.record!(
      action: "created",
      recordable: @page,
      root_recording: @root,
      parent_recording: @root
    ).recording
  end

  teardown do
    Current.actor = nil if defined?(Current)
    FakeOauth.reset!
  end

  test "registers google drive as an attachable upload provider" do
    provider = RecordingStudioAttachable.configuration.upload_provider(:google_drive)

    assert_equal :google_drive, provider.key
    assert_equal :client_picker, provider.strategy
    assert_equal "google_drive", provider.launcher
    assert_equal RecordingStudioGoogleDrive::Attachable::LAUNCHER_MODULE, provider.launcher_module
    assert_equal ["https://www.googleapis.com/auth/drive.readonly"],
                 RecordingStudioGoogleDrive.configuration.scopes
  end

  test "dummy upload page path stays under attachable google_drive" do
    assert_equal(
      "/recording_studio_attachable/google_drive/recordings/#{@recording.id}/bootstrap",
      google_drive.recording_bootstrap_path(@recording)
    )
  end

  test "bootstrap returns connect payload when Drive is not connected" do
    get google_drive.recording_bootstrap_path(@recording, format: :json)

    assert_response :success
    payload = JSON.parse(response.body)
    assert_equal "google_drive", payload.fetch("provider_key")
    assert payload.fetch("needs_auth")
    refute payload.fetch("reconnect")
    assert_equal oauth_outbound_connect_path, payload.dig("connect", "url")
    assert_equal "post", payload.dig("connect", "method")
    assert payload.dig("connect", "fields", "authenticity_token").present?
    assert_includes payload.dig("connect", "fallback_url"), google_drive.recording_connect_path(@recording)
    refute payload.key?("access_token")
    assert_nil session["access_token"]
  end

  test "bootstrap returns picker token when connected" do
    follow_connect!

    get google_drive.recording_bootstrap_path(@recording, format: :json)

    assert_response :success
    payload = JSON.parse(response.body)
    refute payload.fetch("needs_auth")
    assert payload.fetch("access_token").present?
    assert_equal RecordingStudioGoogleDrive.configuration.attachable.api_key, payload.fetch("api_key")
    assert_equal RecordingStudioGoogleDrive.configuration.attachable.app_id, payload.fetch("app_id")
    refute_includes payload.fetch("access_token"), "\n"
  end

  test "bootstrap maps reconnect to ProviderConnect payload" do
    follow_connect!

    RecordingStudioGoogleDrive.stub(:picker_access_token, ->(*) { raise RecordingStudioGoogleDrive::ReconnectRequired, "expired" }) do
      get google_drive.recording_bootstrap_path(@recording, format: :json)
    end

    assert_response :success
    payload = JSON.parse(response.body)
    assert payload.fetch("needs_auth")
    assert payload.fetch("reconnect")
    assert_equal oauth_outbound_connect_path, payload.dig("connect", "url")
    refute payload.key?("access_token")
  end

  test "imports index shows connect when there is no Google Drive connection" do
    get google_drive.recording_imports_path(@recording)

    assert_response :success
    assert_includes response.body, "Connect Google Drive"
    assert_includes response.body, oauth_outbound_connect_path
    refute_includes response.body, "fake-access-"
  end

  test "connected import copies a selected file through ImportRemoteFiles" do
    follow_connect!

    with_drive_client(import_client) do
      get google_drive.recording_imports_path(@recording)
      assert_response :success
      assert_includes response.body, "Brief.pdf"
      assert_includes response.body, "Briefs"
      assert_includes response.body, "application/pdf"
      refute_includes response.body, "mimeType"

      post google_drive.recording_imports_path(@recording), params: { file_ids: ["file-1"] }
      assert_nil flash[:alert], flash[:alert].to_s
      assert_response :redirect
    end

    imported_ids = RecordingStudio::Recording.unscoped.where(
      parent_recording_id: @recording.id,
      recordable_type: "RecordingStudioAttachable::Attachment"
    ).pluck(:recordable_id)
    attachment = RecordingStudioAttachable::Attachment.find_by(id: imported_ids, original_filename: "Brief.pdf")
    assert attachment
    assert_equal "Imported from Google Drive", attachment.description
  end

  test "shared attachment imports path maps reconnect errors" do
    follow_connect!
    client = Object.new
    client.define_singleton_method(:fetch_file) do |*_args, **|
      raise RecordingStudioGoogleDrive::ReconnectRequired, "expired"
    end

    path = "/recording_studio_attachable/recordings/#{@recording.id}/attachments/imports"
    with_drive_client(client) do
      post path,
           params: {
             attachment_import: {
               provider_key: "google_drive",
               attachments: [{ provider_payload: { id: "file-1" } }]
             }
           },
           as: :json
    end

    assert_response :unprocessable_entity, "#{path} #{response.status} #{response.body}"
    payload = JSON.parse(response.body)
    assert_equal "Reconnect Google Drive to continue", payload.fetch("error")
    assert_equal oauth_outbound_connect_path, payload.dig("errors", "url")
  end

  test "html import create maps reconnect to connect payload" do
    follow_connect!
    client = Object.new
    client.define_singleton_method(:fetch_file) do |*_args, **|
      raise RecordingStudioGoogleDrive::ReconnectRequired, "expired"
    end

    with_drive_client(client) do
      post google_drive.recording_imports_path(@recording), params: { file_ids: ["file-1"] }, as: :json
    end

    assert_response :unauthorized
    payload = JSON.parse(response.body)
    assert_equal "Reconnect Google Drive to continue", payload.fetch("error")
    assert_equal oauth_outbound_connect_path, payload.dig("connect", "url")
  end

  private

  def follow_connect!
    get google_drive.recording_imports_path(@recording)
    assert_response :success
    post oauth_outbound_connect_path, params: {
      authenticity_token: authenticity_token,
      owner: "user",
      return_to: google_drive.recording_imports_path(@recording)
    }
    assert_response :redirect
    follow_redirect!
    assert_response :redirect
    follow_redirect!
    assert_response :redirect
    follow_redirect!
  end

  def with_drive_client(client, &)
    RecordingStudioGoogleDrive::Attachable::Integration.stub(:client, ->(**) { client }, &)
  end

  def import_client
    drive_file = RecordingStudioGoogleDrive::DriveFile.new(
      id: "file-1",
      name: "Brief.pdf",
      mime_type: "application/pdf",
      size: 12,
      modified_at: nil,
      web_view_link: "https://drive.test/file-1",
      resource_key: nil
    )
    downloaded = RecordingStudioGoogleDrive::DownloadedFile.new(
      body: "%PDF-1.4\nbrief",
      filename: "Brief.pdf",
      content_type: "application/pdf"
    )
    folder = RecordingStudioGoogleDrive::DriveFile.new(
      id: "folder-1",
      name: "Briefs",
      mime_type: RecordingStudioGoogleDrive::FOLDER_MIME_TYPE,
      size: nil,
      modified_at: nil,
      web_view_link: nil,
      resource_key: nil
    )
    client = Object.new
    client.define_singleton_method(:list) do |**|
      RecordingStudioGoogleDrive::Page.new(entries: [folder, drive_file], next_cursor: nil)
    end
    client.define_singleton_method(:fetch_file) { |_id, resource_key: nil| drive_file }
    client.define_singleton_method(:download) { |_id, resource_key: nil| downloaded }
    client
  end

  def authenticity_token
    css_select('input[name="authenticity_token"]').first&.[]("value") ||
      css_select('meta[name="csrf-token"]').first&.[]("content")
  end

  def oauth_outbound_connect_path
    RecordingStudioOauth::Engine.routes.url_helpers.outbound_connect_path(provider: "google_drive")
  end

  def grant_workspace_access!(root, actor: @user, role: :admin)
    original = RecordingStudioAccessible.configuration.access_management_authorizer
    RecordingStudioAccessible.configuration.access_management_authorizer = ->(**) { true }
    result = RecordingStudioAccessible.grant_access(
      recording: root,
      actor: actor,
      role: role,
      manager_actor: @user
    )
    raise result.error if result.failure?
  ensure
    RecordingStudioAccessible.configuration.access_management_authorizer = original
  end
end
