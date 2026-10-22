# frozen_string_literal: true

require "json"
require "stringio"
require "test_helper"
require "webmock/minitest"

class ClientTest < Minitest::Test
  def setup
    WebMock.enable!
    WebMock.disable_net_connect!
    WebMock.reset!
  end

  def teardown
    WebMock.reset!
    WebMock.allow_net_connect!
  end

  def test_search_escapes_backslashes_before_quotes
    requests = stub_list_page("files" => [])

    client.search("foo\\bar'baz")

    q = query_params(requests.first.uri).fetch("q")
    assert_equal "trashed = false and name contains 'foo\\\\bar\\'baz'", q
  end

  def test_search_escapes_quote_break_payload_in_q
    requests = stub_list_page("files" => [])
    payload = "' or name contains 'secret"

    client.search(payload)

    q = query_params(requests.first.uri).fetch("q")
    refute_includes q, "name contains '#{payload}'"
    assert_equal "trashed = false and name contains '\\' or name contains \\'secret'", q
  end

  def test_list_walks_page_two_with_the_cursor
    stub_request(:get, %r{https://www.googleapis.com/drive/v3/files})
      .to_return do |request|
        params = query_params(request.uri)
        if params["pageToken"] == "cursor-2"
          json_http(files: [{ "id" => "b", "name" => "Two", "mimeType" => "text/plain" }])
        else
          json_http(
            files: [{ "id" => "a", "name" => "One", "mimeType" => "text/plain" }],
            nextPageToken: "cursor-2"
          )
        end
      end

    page_one = client.list
    assert_equal ["a"], page_one.entries.map(&:id)
    assert_equal "cursor-2", page_one.next_cursor
    assert page_one.more?

    page_two = client.list(cursor: page_one.next_cursor)
    assert_equal ["b"], page_two.entries.map(&:id)
    assert_nil page_two.next_cursor
    refute page_two.more?

    assert_requested(:get, %r{https://www.googleapis.com/drive/v3/files}) do |request|
      query_params(request.uri)["pageToken"] == "cursor-2"
    end
  end

  def test_list_browses_a_parent_folder
    requests = stub_list_page("files" => [])

    client.list(parent_id: "root")

    assert_equal "trashed = false and 'root' in parents", query_params(requests.first.uri).fetch("q")
  end

  def test_fetch_file_returns_metadata_and_encodes_the_id
    stub_request(:get, %r{https://www.googleapis.com/drive/v3/files/file%2F1})
      .to_return(json_http(
                   id: "file/1",
                   name: "Preview",
                   mimeType: "image/png",
                   resourceKey: "rk-1",
                   webViewLink: "https://drive.google.test/file/1"
                 ))

    file = client.fetch_file("file/1", resource_key: "rk-1")

    assert_equal "file/1", file.id
    assert_equal "Preview", file.name
    assert_equal "image/png", file.mime_type
    assert_equal "rk-1", file.resource_key
    refute file.folder?
    assert_requested(:get, %r{https://www.googleapis.com/drive/v3/files/file%2F1}) do |request|
      params = query_params(request.uri)
      params["resourceKey"] == "rk-1" && params["supportsAllDrives"] == "true"
    end
  end

  def test_download_exports_google_docs_to_pdf
    stub_download_export(
      id: "doc-1",
      name: "Project brief",
      mime_type: "application/vnd.google-apps.document",
      export_type: "application/pdf",
      body: "pdf-binary"
    )

    downloaded = client.download("doc-1")

    assert_equal "Project brief.pdf", downloaded.filename
    assert_equal "application/pdf", downloaded.content_type
    assert_equal "pdf-binary", downloaded.body
  end

  def test_download_exports_sheets_slides_and_drawings
    {
      "application/vnd.google-apps.spreadsheet" => ["text/csv", ".csv", "sheet-csv"],
      "application/vnd.google-apps.presentation" => ["application/pdf", ".pdf", "slides-pdf"],
      "application/vnd.google-apps.drawing" => ["image/png", ".png", "drawing-png"]
    }.each do |mime_type, (export_type, extension, body)|
      WebMock.reset!
      stub_download_export(
        id: "export-1",
        name: "Board",
        mime_type: mime_type,
        export_type: export_type,
        body: body
      )

      downloaded = client.download("export-1")

      assert_equal "Board#{extension}", downloaded.filename
      assert_equal export_type, downloaded.content_type
      assert_equal body, downloaded.body
    end
  end

  def test_download_reads_binary_media_and_follows_usercontent_redirect
    stub_request(:get, "https://www.googleapis.com/drive/v3/files/file-1")
      .with(query: hash_including("fields"))
      .to_return(json_http(id: "file-1", name: "Preview.png", mimeType: "image/png"))
    stub_request(:get, "https://www.googleapis.com/drive/v3/files/file-1")
      .with(query: hash_including("alt" => "media"))
      .to_return(status: 302, headers: { "Location" => "https://lh3.googleusercontent.com/download/abc" })
    stub_request(:get, "https://lh3.googleusercontent.com/download/abc")
      .to_return(status: 200, body: "image-bytes")

    downloaded = client.download("file-1")

    assert_equal "Preview.png", downloaded.filename
    assert_equal "image/png", downloaded.content_type
    assert_equal "image-bytes", downloaded.body
    assert_requested(:get, "https://www.googleapis.com/drive/v3/files/file-1") do |request|
      request.headers["Authorization"] == "Bearer access-token" &&
        query_params(request.uri)["alt"] == "media"
    end
    assert_requested(:get, "https://lh3.googleusercontent.com/download/abc") do |request|
      request.headers["Authorization"].nil?
    end
  end

  def test_upload_file_posts_multipart_metadata_and_bytes
    stub_request(:post, %r{https://www.googleapis.com/upload/drive/v3/files})
      .to_return(json_http(id: "new-1", name: "notes.txt", mimeType: "text/plain"))

    uploaded = client.upload_file(
      io: StringIO.new("hello"),
      filename: "notes.txt",
      content_type: "text/plain",
      parent_id: "root"
    )

    assert_equal "new-1", uploaded.id
    assert_requested(:post, %r{https://www.googleapis.com/upload/drive/v3/files}) do |request|
      request.uri.query.include?("uploadType=multipart") &&
        request.body.include?("\"name\":\"notes.txt\"") &&
        request.body.include?("\"parents\":[\"root\"]") &&
        request.body.include?("hello") &&
        request.headers["Content-Type"].start_with?("multipart/related; boundary=")
    end
  end

  def test_upload_accepts_non_ascii_filename_with_binary_body
    binary = "\x00\xFF\x80".b
    stub_request(:post, %r{https://www.googleapis.com/upload/drive/v3/files})
      .to_return(json_http(id: "pdf-1", name: "résumé.pdf", mimeType: "application/pdf"))

    uploaded = client.upload_file(
      io: binary,
      filename: "résumé.pdf",
      content_type: "application/pdf"
    )

    assert_equal "pdf-1", uploaded.id
    assert_requested(:post, %r{https://www.googleapis.com/upload/drive/v3/files}) do |request|
      body = request.body.b
      body.include?("Content-Type: application/pdf\r\n\r\n".b) &&
        body.include?(JSON.generate(name: "résumé.pdf", mimeType: "application/pdf").b) &&
        body.include?(binary)
    end
  end

  def test_expired_token_raises_reconnect_required
    stub_list_error(
      status: 401,
      body: { error: { code: 401, status: "UNAUTHENTICATED" } }
    )

    error = assert_raises(RecordingStudioGoogleDrive::ReconnectRequired) { client.list }
    assert_kind_of RecordingStudioGoogleDrive::Error, error
    refute_includes error.message, "UNAUTHENTICATED secret"
    assert_includes error.message, "HTTP 401"
  end

  def test_invalid_grant_on_400_raises_reconnect_required
    stub_list_error(status: 400, body: { error: "invalid_grant", error_description: "token expired" })

    error = assert_raises(RecordingStudioGoogleDrive::ReconnectRequired) { client.list }
    refute_includes error.message, "token expired"
    assert_includes error.message, "invalid_grant"
  end

  def test_invalid_grant_on_401_raises_reconnect_required
    stub_list_error(status: 401, body: { error: "invalid_grant" })

    assert_raises(RecordingStudioGoogleDrive::ReconnectRequired) { client.list }
  end

  def test_revoked_token_raises_reconnect_required
    stub_request(:get, %r{https://www.googleapis.com/drive/v3/files/file-1})
      .to_return(status: 401, body: { error: "invalid_token" }.to_json)

    assert_raises(RecordingStudioGoogleDrive::ReconnectRequired) { client.fetch_file("file-1") }
  end

  def test_insufficient_scope_raises_reconnect_required
    stub_list_error(status: 403, body: { error: { code: 403, status: "ACCESS_TOKEN_SCOPE_INSUFFICIENT" } })

    assert_raises(RecordingStudioGoogleDrive::ReconnectRequired) { client.list }
  end

  def test_file_permission_denied_is_not_reconnect
    stub_request(:get, %r{https://www.googleapis.com/drive/v3/files/file-1})
      .to_return(
        status: 403,
        body: {
          error: {
            code: 403,
            status: "PERMISSION_DENIED",
            errors: [{ reason: "insufficientPermissions" }]
          }
        }.to_json
      )

    error = assert_raises(RecordingStudioGoogleDrive::RequestError) { client.fetch_file("file-1") }
    assert_equal 403, error.status
    assert_equal "PERMISSION_DENIED", error.code
    refute_includes error.message, "insufficientPermissions"
  end

  def test_server_error_raises_request_error_not_reconnect
    stub_list_error(status: 500, body: { error: { code: 500, message: "backend exploded", status: "INTERNAL" } })

    error = assert_raises(RecordingStudioGoogleDrive::RequestError) { client.list }
    refute_kind_of RecordingStudioGoogleDrive::ReconnectRequired, error
    assert_equal 500, error.status
    refute_includes error.message, "backend exploded"
    assert_includes error.message, "HTTP 500"
    assert_includes error.message, "INTERNAL"
  end

  def test_socket_error_is_wrapped_as_request_error_with_timeouts
    captured = {}
    Net::HTTP.stub(:start, lambda { |_host, _port, **options, &_|
      captured.replace(options)
      raise SocketError, "fail"
    }) do
      error = assert_raises(RecordingStudioGoogleDrive::RequestError) { client.list }
      refute_kind_of RecordingStudioGoogleDrive::ReconnectRequired, error
      assert_includes error.message, "SocketError"
    end

    assert_equal true, captured[:use_ssl]
    assert_equal 10, captured[:open_timeout]
    assert_equal 30, captured[:read_timeout]
    assert_equal 30, captured[:write_timeout]
  end

  def test_callable_and_access_token_object_both_work
    requests = stub_list_page("files" => [])
    provider = Struct.new(:access_token).new("object-token")

    RecordingStudioGoogleDrive::Client.new(token_provider: -> { "lambda-token" }).list
    RecordingStudioGoogleDrive::Client.new(token_provider: provider).list

    assert_equal(
      ["Bearer lambda-token", "Bearer object-token"],
      requests.map { |request| request.headers["Authorization"] }
    )
  end

  private

  def client
    RecordingStudioGoogleDrive::Client.new(token_provider: -> { "access-token" })
  end

  def stub_list_page(payload)
    requests = []
    stub_request(:get, %r{https://www.googleapis.com/drive/v3/files})
      .with do |request|
        requests << request
        true
      end
      .to_return(json_http(payload))
    requests
  end

  def stub_list_error(status:, body:)
    stub_request(:get, %r{https://www.googleapis.com/drive/v3/files})
      .to_return(status: status, body: body.to_json)
  end

  def stub_download_export(id:, name:, mime_type:, export_type:, body:)
    stub_request(:get, "https://www.googleapis.com/drive/v3/files/#{id}")
      .with(query: hash_including("fields"))
      .to_return(json_http(id: id, name: name, mimeType: mime_type))
    stub_request(:get, "https://www.googleapis.com/drive/v3/files/#{id}/export")
      .with(query: hash_including("mimeType" => export_type))
      .to_return(status: 200, body: body)
  end

  def json_http(payload)
    { status: 200, headers: { "Content-Type" => "application/json" }, body: payload.to_json }
  end

  def query_params(uri)
    URI.decode_www_form(URI.parse(uri.to_s).query.to_s).to_h
  end
end
