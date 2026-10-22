# frozen_string_literal: true

require "json"
require "net/http"
require "stringio"
require "test_helper"

class ClientTest < Minitest::Test
  FakeResponse = Struct.new(:body, :code, :headers, :success, keyword_init: true) do
    def [](key)
      headers[key]
    end

    def is_a?(klass)
      return success if klass == Net::HTTPSuccess

      super
    end
  end

  FakeRedirectResponse = Struct.new(:body, :code, :headers, keyword_init: true) do
    def [](key)
      headers[key]
    end

    def is_a?(klass)
      return true if klass == Net::HTTPRedirection

      super
    end
  end

  def test_list_files_pages_and_escapes_search
    captured = { requests: [] }
    response = json_response(
      "files" => [
        { "id" => "file-1", "name" => "Brief", "mimeType" => "application/pdf", "size" => "12" }
      ],
      "nextPageToken" => "next-page"
    )

    stub_start(responses: [response], captured: captured) do
      page = client.list_files(query: "O'Hara", page_token: "page-2", page_size: 10)

      assert_equal 1, page.files.size
      assert_equal "file-1", page.files.first.id
      assert_equal "Brief", page.files.first.name
      assert_equal "next-page", page.next_page_token
    end

    params = query_params(captured[:requests].first.fetch(:path))
    assert_equal "10", params.fetch("pageSize")
    assert_equal "page-2", params.fetch("pageToken")
    assert_equal "true", params.fetch("supportsAllDrives")
    assert_equal "trashed = false and name contains 'O\\'Hara'", params.fetch("q")
    assert_equal "Bearer access-token", captured[:requests].first.fetch(:authorization)
  end

  def test_list_files_browses_a_parent_folder
    captured = { requests: [] }
    response = json_response("files" => [])

    stub_start(responses: [response], captured: captured) do
      client.list_files(parent_id: "root")
    end

    params = query_params(captured[:requests].first.fetch(:path))
    assert_equal "trashed = false and 'root' in parents", params.fetch("q")
  end

  def test_fetch_file_returns_metadata_and_encodes_the_id
    captured = { requests: [] }
    response = json_response(
      "id" => "file/1",
      "name" => "Preview",
      "mimeType" => "image/png",
      "resourceKey" => "rk-1",
      "webViewLink" => "https://drive.google.test/file/1"
    )

    stub_start(responses: [response], captured: captured) do
      file = client.fetch_file("file/1", resource_key: "rk-1")

      assert_equal "file/1", file.id
      assert_equal "Preview", file.name
      assert_equal "image/png", file.mime_type
      assert_equal "rk-1", file.resource_key
      refute file.folder?
    end

    path, query = captured[:requests].first.fetch(:path).split("?", 2)
    params = URI.decode_www_form(query).to_h
    assert_equal "/drive/v3/files/file%2F1", path
    assert_equal "rk-1", params.fetch("resourceKey")
    assert_equal "true", params.fetch("supportsAllDrives")
  end

  def test_download_file_exports_google_docs_to_pdf
    captured = { requests: [] }
    metadata = json_response(
      "id" => "doc-1",
      "name" => "Project brief",
      "mimeType" => "application/vnd.google-apps.document"
    )
    export = FakeResponse.new(body: "pdf-binary", code: "200", headers: {}, success: true)

    stub_start(responses: [metadata, export], captured: captured) do
      downloaded = client.download_file("doc-1")

      assert_equal "doc-1", downloaded.id
      assert_equal "Project brief.pdf", downloaded.filename
      assert_equal "application/pdf", downloaded.content_type
      assert_equal "pdf-binary", downloaded.body
    end

    export_path, export_query = captured[:requests][1].fetch(:path).split("?", 2)
    params = URI.decode_www_form(export_query).to_h
    assert_equal "/drive/v3/files/doc-1/export", export_path
    assert_equal "application/pdf", params.fetch("mimeType")
  end

  def test_download_file_reads_binary_media_and_follows_usercontent_redirect
    captured = { requests: [] }
    metadata = json_response(
      "id" => "file-1",
      "name" => "Preview.png",
      "mimeType" => "image/png"
    )
    redirect = FakeRedirectResponse.new(
      body: "",
      code: "302",
      headers: { "location" => "https://lh3.googleusercontent.com/download/abc" }
    )
    bytes = FakeResponse.new(body: "image-bytes", code: "200", headers: {}, success: true)

    stub_start(responses: [metadata, redirect, bytes], captured: captured) do
      downloaded = client.download_file("file-1")

      assert_equal "Preview.png", downloaded.filename
      assert_equal "image/png", downloaded.content_type
      assert_equal "image-bytes", downloaded.body
    end

    media_params = query_params(captured[:requests][1].fetch(:path))
    assert_equal "media", media_params.fetch("alt")
    assert_equal "Bearer access-token", captured[:requests][1].fetch(:authorization)
    assert_equal "lh3.googleusercontent.com", captured[:requests][2].fetch(:host)
    assert_nil captured[:requests][2].fetch(:authorization)
  end

  def test_upload_file_posts_multipart_metadata_and_bytes
    captured = { requests: [] }
    response = json_response(
      "id" => "new-1",
      "name" => "notes.txt",
      "mimeType" => "text/plain",
      "webViewLink" => "https://drive.google.test/new-1"
    )

    stub_start(responses: [response], captured: captured) do
      uploaded = client.upload_file(
        io: StringIO.new("hello"),
        filename: "notes.txt",
        content_type: "text/plain",
        parent_id: "root"
      )

      assert_equal "new-1", uploaded.id
      assert_equal "notes.txt", uploaded.name
    end

    request = captured[:requests].first
    assert_equal "www.googleapis.com", request.fetch(:host)
    assert_includes request.fetch(:path), "/upload/drive/v3/files"
    assert_includes request.fetch(:path), "uploadType=multipart"
    assert_includes request.fetch(:body), "\"name\":\"notes.txt\""
    assert_includes request.fetch(:body), "\"parents\":[\"root\"]"
    assert_includes request.fetch(:body), "hello"
    assert_match(%r{\Amultipart/related; boundary=}, request.fetch(:content_type))
  end

  def test_expired_token_raises_reconnect_required
    response = FakeResponse.new(
      body: { "error" => { "code" => 401, "status" => "UNAUTHENTICATED" } }.to_json,
      code: "401",
      headers: {},
      success: false
    )

    stub_start(responses: [response]) do
      error = assert_raises(RecordingStudioGoogleDrive::ReconnectRequired) do
        client.list_files
      end

      assert_kind_of RecordingStudioGoogleDrive::Error, error
    end
  end

  def test_revoked_token_raises_reconnect_required
    response = FakeResponse.new(
      body: { "error" => "invalid_token" }.to_json,
      code: "401",
      headers: {},
      success: false
    )

    stub_start(responses: [response]) do
      assert_raises(RecordingStudioGoogleDrive::ReconnectRequired) do
        client.fetch_file("file-1")
      end
    end
  end

  def test_insufficient_scope_raises_reconnect_required
    response = FakeResponse.new(
      body: { "error" => { "code" => 403, "status" => "ACCESS_TOKEN_SCOPE_INSUFFICIENT" } }.to_json,
      code: "403",
      headers: {},
      success: false
    )

    stub_start(responses: [response]) do
      assert_raises(RecordingStudioGoogleDrive::ReconnectRequired) do
        client.list_files
      end
    end
  end

  def test_file_permission_denied_is_not_reconnect
    response = FakeResponse.new(
      body: {
        "error" => {
          "code" => 403,
          "status" => "PERMISSION_DENIED",
          "errors" => [{ "reason" => "insufficientPermissions" }]
        }
      }.to_json,
      code: "403",
      headers: {},
      success: false
    )

    stub_start(responses: [response]) do
      assert_raises(RecordingStudioGoogleDrive::RequestError) do
        client.fetch_file("file-1")
      end
    end
  end

  def test_callable_and_access_token_object_both_work
    captured = { requests: [] }
    response = json_response("files" => [])
    provider = Struct.new(:access_token).new("object-token")

    stub_start(responses: [response, response], captured: captured) do
      RecordingStudioGoogleDrive::Client.new(token_provider: -> { "lambda-token" }).list_files
      RecordingStudioGoogleDrive::Client.new(token_provider: provider).list_files
    end

    assert_equal "Bearer lambda-token", captured[:requests][0].fetch(:authorization)
    assert_equal "Bearer object-token", captured[:requests][1].fetch(:authorization)
  end

  private

  def client
    RecordingStudioGoogleDrive::Client.new(token_provider: -> { "access-token" })
  end

  def json_response(hash)
    FakeResponse.new(body: hash.to_json, code: "200", headers: {}, success: true)
  end

  def query_params(path)
    _path, query = path.split("?", 2)
    URI.decode_www_form(query.to_s).to_h
  end

  def stub_start(responses:, captured: nil, &)
    queue = responses.dup
    captured ||= { requests: [] }
    captured[:requests] ||= []

    Net::HTTP.stub(:start, lambda { |host, _port, **options, &http_block|
      assert_equal true, options[:use_ssl]
      http = Object.new
      http.define_singleton_method(:request) do |request|
        captured[:requests] << {
          host: host,
          path: request.path,
          authorization: request["Authorization"],
          body: request.body,
          content_type: request["Content-Type"]
        }
        queue.shift
      end
      http_block.call(http)
    }, &)
  end
end
