# frozen_string_literal: true

require "test_helper"

class GoogleDriveApiTest < ActionDispatch::IntegrationTest
  BASE = "/recording_studio_api/api/v1"

  setup do
    @previous_actor = Current.actor
    @owner = user("owner")
    @editor = user("editor")
    @viewer = user("viewer")
    Current.actor = @owner
    @workspace = Workspace.create!(name: "Drive API #{SecureRandom.hex(4)}")
    @root = RecordingStudio.root_recording_for(@workspace)
    @owner_access = bootstrap!(@root, @owner)
    @editor_access = grant!(@editor, :edit)
    @viewer_access = grant!(@viewer, :view)
    @editor_token = token_for(@editor_access)
    @viewer_token = token_for(@viewer_access)
    @page = @root.record(Page, actor: @owner) { |page| page.title = "Notes" }
    @file = RecordingStudioGoogleDrive::DriveFile.new(
      id: "file-1",
      name: "Brief.pdf",
      mime_type: "application/pdf",
      size: 12,
      modified_at: nil,
      web_view_link: "https://drive.test/file-1",
      resource_key: nil
    )
    @drive_page = RecordingStudioGoogleDrive::Page.new(entries: [@file], next_cursor: "cursor-2")
  end

  teardown do
    Current.actor = @previous_actor
  end

  test "list succeeds for an editor and is denied for a viewer" do
    listed = nil
    page = @drive_page
    client = drive_client
    client.define_singleton_method(:list) do |**kwargs|
      listed = kwargs
      page
    end

    with_drive_client(client) do
      payload = call(:get, "/google_drive/list", @editor_token, recording_id: @page.id, parent_id: "folder-1")
      assert_response :success, response.body
      assert_equal "file-1", payload.fetch("entries").first.fetch("id")
      assert_equal "cursor-2", payload.fetch("next_cursor")
      refute payload.key?("more")
      assert_equal "folder-1", listed.fetch(:parent_id)

      call(:get, "/google_drive/list", @viewer_token, recording_id: @page.id)
      assert_response :forbidden
      assert_equal "forbidden", json.dig("error", "code")
    end
  end

  test "search succeeds for an editor and is denied for a viewer" do
    searched = nil
    page = @drive_page
    client = drive_client
    client.define_singleton_method(:search) do |**kwargs|
      searched = kwargs
      page
    end

    with_drive_client(client) do
      payload = call(:get, "/google_drive/search", @editor_token, recording_id: @page.id, query: "brief")
      assert_response :success, response.body
      assert_equal "Brief.pdf", payload.fetch("entries").first.fetch("name")
      refute payload.key?("more")
      assert_equal "brief", searched.fetch(:query)

      call(:get, "/google_drive/search", @viewer_token, recording_id: @page.id, query: "brief")
      assert_response :forbidden
      assert_equal "forbidden", json.dig("error", "code")
    end
  end

  test "import succeeds for an editor and is denied for a viewer" do
    with_drive_client(import_client) do
      payload = call(
        :post,
        "/google_drive/import",
        @editor_token,
        recording_id: @page.id,
        attachments: [{ id: "file-1" }]
      )
      assert_response :success, response.body
      imported = payload.fetch("attachments").first
      attachment_id = imported.fetch("id")
      attachment = RecordingStudio::Recording.find(attachment_id)
      assert_equal @page.id, attachment.parent_recording_id
      assert_equal "RecordingStudioAttachable::Attachment", attachment.recordable_type
      assert_equal "Brief.pdf", attachment.recordable.original_filename
      assert_equal "Brief.pdf", imported.fetch("name")
      assert_equal attachment.recordable.attachment_kind, imported.fetch("kind")

      call(
        :post,
        "/google_drive/import",
        @viewer_token,
        recording_id: @page.id,
        attachments: [{ id: "file-1" }]
      )
      assert_response :forbidden
      assert_equal "forbidden", json.dig("error", "code")
    end
  end

  test "list returns a second page for the next cursor" do
    listed = []
    page_one = @drive_page
    page_two = RecordingStudioGoogleDrive::Page.new(entries: [@file], next_cursor: nil)
    client = drive_client
    client.define_singleton_method(:list) do |**kwargs|
      listed << kwargs
      kwargs[:cursor].to_s == "cursor-2" ? page_two : page_one
    end

    with_drive_client(client) do
      first = call(:get, "/google_drive/list", @editor_token, recording_id: @page.id)
      assert_response :success, response.body
      assert_equal "cursor-2", first.fetch("next_cursor")

      second = call(:get, "/google_drive/list", @editor_token, recording_id: @page.id, cursor: first.fetch("next_cursor"))
      assert_response :success, response.body
      assert_nil second.fetch("next_cursor")
      refute second.key?("more")
      assert_equal "cursor-2", listed.last.fetch(:cursor)
    end
  end

  test "search returns a second page for the next cursor" do
    searched = []
    page_one = @drive_page
    page_two = RecordingStudioGoogleDrive::Page.new(entries: [@file], next_cursor: nil)
    client = drive_client
    client.define_singleton_method(:search) do |**kwargs|
      searched << kwargs
      kwargs[:cursor].to_s == "cursor-2" ? page_two : page_one
    end

    with_drive_client(client) do
      first = call(:get, "/google_drive/search", @editor_token, recording_id: @page.id, query: "brief")
      assert_response :success, response.body
      assert_equal "cursor-2", first.fetch("next_cursor")

      second = call(
        :get,
        "/google_drive/search",
        @editor_token,
        recording_id: @page.id,
        query: "brief",
        cursor: first.fetch("next_cursor")
      )
      assert_response :success, response.body
      assert_nil second.fetch("next_cursor")
      refute second.key?("more")
      assert_equal "cursor-2", searched.last.fetch(:cursor)
    end
  end

  test "list without a token is unauthorized" do
    call_without_token(:get, "/google_drive/list", recording_id: @page.id)
    assert_response :unauthorized
    assert_equal "authentication_failed", json.dig("error", "code")
  end

  test "search without a token is unauthorized" do
    call_without_token(:get, "/google_drive/search", recording_id: @page.id, query: "brief")
    assert_response :unauthorized
    assert_equal "authentication_failed", json.dig("error", "code")
  end

  test "import without a token is unauthorized" do
    call_without_token(:post, "/google_drive/import", recording_id: @page.id, attachments: [{ id: "file-1" }])
    assert_response :unauthorized
    assert_equal "authentication_failed", json.dig("error", "code")
  end

  test "excluded operations are not exposed on the public API" do
    names = RecordingStudioApi.configuration.registered_endpoint_registry.all.map(&:name)
    assert_includes names, "google_drive.list"
    assert_includes names, "google_drive.search"
    assert_includes names, "google_drive.import"
    refute_includes names, "picker_access_token"
    refute_includes names, "google_drive.connect"
    refute_includes names, "google_drive.disconnect"
    refute_includes names, "google_drive.fetch_file"
    refute_includes names, "google_drive.download"
    refute_includes names, "google_drive.upload_file"

    document = RecordingStudioApi.openapi_document
    summaries = document.fetch(:paths).values.flat_map(&:values).filter_map { |operation| operation[:summary] }
    assert_includes summaries, "Google Drive - List"
    assert_includes summaries, "Google Drive - Search"
    assert_includes summaries, "Google Drive - Import"

    registered = RecordingStudioApi.configuration.registered_endpoint_registry.all
    titles = registered.filter_map { |endpoint| endpoint.openapi&.[](:title) || endpoint.openapi&.[]("title") }
    assert_includes titles, "Google Drive - List"
    assert_includes titles, "Google Drive - Search"
    assert_includes titles, "Google Drive - Import"

    paths = document.fetch(:paths).keys
    refute(paths.any? { |path| path.include?("picker") })
    refute(paths.any? { |path| path.include?("connect") })
    refute(paths.any? { |path| path.include?("fetch_file") })
    refute(paths.any? { |path| path.include?("upload_file") })
  end

  private

  def user(name)
    User.create!(
      email: "#{name}-#{SecureRandom.hex(4)}@example.com",
      password: "Password123!",
      password_confirmation: "Password123!"
    )
  end

  def bootstrap!(recording, actor)
    result = RecordingStudioAccessible.bootstrap_owner_access!(recording: recording, actor: actor)
    raise result.error if result.failure?

    result.value
  end

  def grant!(actor, role)
    result = RecordingStudioAccessible.grant_access(
      recording: @root,
      actor: actor,
      role: role,
      manager_actor: @owner
    )
    raise result.error if result.failure?

    result.value
  end

  def token_for(access_recording)
    provision = RecordingStudioApi::Services::ProvisionApiClient.call(
      access_point_recording: access_recording.parent_recording || access_recording.root_recording,
      manager_actor: @owner,
      role: access_recording.recordable.role,
      name: "Client #{SecureRandom.hex(3)}"
    )
    raise provision.error unless provision.success?

    issued = RecordingStudioApi::Services::IssueOauthAccessToken.call(
      grant_type: "client_credentials",
      client_id: provision.value.fetch(:credential).oauth_client_id,
      client_secret: provision.value.fetch(:token)
    )
    raise issued.error unless issued.success?

    issued.value.fetch(:access_token)
  end

  def headers(token)
    { "Authorization" => "Bearer #{token}", "Accept" => "application/json" }
  end

  def call(method, path, token, params = {})
    request_endpoint(method, path, params, headers(token))
  end

  def call_without_token(method, path, params = {})
    request_endpoint(method, path, params, { "Accept" => "application/json" })
  end

  def request_endpoint(method, path, params, request_headers)
    if method == :get
      send(method, "#{BASE}#{path}", params: params, headers: request_headers)
    else
      send(method, "#{BASE}#{path}", params: params, headers: request_headers, as: :json)
    end
    response.media_type.to_s.include?("json") ? JSON.parse(response.body) : {}
  rescue JSON::ParserError
    {}
  end

  def json
    JSON.parse(response.body)
  end

  def drive_client
    Object.new
  end

  def import_client
    file = @file
    downloaded = RecordingStudioGoogleDrive::DownloadedFile.new(
      body: "%PDF-1.4\nbrief",
      filename: "Brief.pdf",
      content_type: "application/pdf"
    )
    client = Object.new
    client.define_singleton_method(:fetch_file) { |id, resource_key: nil| file }
    client.define_singleton_method(:download) { |id, resource_key: nil, max_bytes: nil| downloaded }
    client
  end

  def with_drive_client(client, &)
    RecordingStudioGoogleDrive::Attachable::Integration.stub(:client, ->(**) { client }, &)
  end
end
