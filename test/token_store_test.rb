# frozen_string_literal: true

require "json"
require "test_helper"
require "webmock/minitest"

class TokenStoreTest < Minitest::Test
  FakeConnection = Struct.new(:access_token)

  def setup
    @root = Object.new
    @actor = Object.new
    WebMock.enable!
    WebMock.disable_net_connect!
    WebMock.reset!
  end

  def teardown
    WebMock.reset!
    WebMock.allow_net_connect!
  end

  def test_token_found
    connection = FakeConnection.new("ya29.live")

    with_connection(connection) do |calls|
      store = RecordingStudioGoogleDrive::TokenStore.new(root: @root, actor: @actor)

      assert_equal "ya29.live", store.call
      assert_equal [{ provider: :google_drive, root: @root, actor: @actor }], calls
      assert_equal "ya29.live", store.access_token
    end
  end

  def test_ready_token_is_returned
    connection = FakeConnection.new("ya29.refreshed")

    with_connection(connection) do
      store = RecordingStudioGoogleDrive::TokenStore.new(root: @root, actor: @actor)

      assert_equal "ya29.refreshed", store.call
    end
  end

  def test_no_connection_raises_reconnect_required
    with_connection(nil) do
      error = assert_raises(RecordingStudioGoogleDrive::ReconnectRequired) do
        RecordingStudioGoogleDrive::TokenStore.new(root: @root, actor: @actor).call
      end

      assert_equal "Google Drive needs connecting again", error.message
      refute_includes error.message, "ya29"
      refute_includes error.inspect, "ya29"
    end
  end

  def test_refresh_failure_raises_reconnect_required
    with_connection(nil) do
      error = assert_raises(RecordingStudioGoogleDrive::ReconnectRequired) do
        RecordingStudioGoogleDrive::Client.for(root: @root, actor: @actor).list
      end

      assert_kind_of RecordingStudioGoogleDrive::ReconnectRequired, error
      refute_includes error.message, "invalid_grant"
      refute_includes error.message, "refresh_token"
    end
  end

  def test_client_for_sends_the_oauth_token
    requests = []
    stub_request(:get, %r{https://www.googleapis.com/drive/v3/files})
      .with do |request|
        requests << request
        true
      end
      .to_return(
        status: 200,
        headers: { "Content-Type" => "application/json" },
        body: { "files" => [] }.to_json
      )

    with_connection(FakeConnection.new("ya29.from-oauth")) do
      RecordingStudioGoogleDrive::Client.for(root: @root, actor: @actor).list
    end

    assert_equal(["Bearer ya29.from-oauth"], requests.map { |request| request.headers["Authorization"] })
  end

  def test_root_and_actor_are_required
    assert_raises(ArgumentError) { RecordingStudioGoogleDrive::TokenStore.new(root: nil, actor: @actor) }
    assert_raises(ArgumentError) { RecordingStudioGoogleDrive::TokenStore.new(root: @root, actor: nil) }
  end

  private

  def with_connection(connection)
    calls = []
    lookup = lambda do |provider:, root:, actor:|
      calls << { provider: provider, root: root, actor: actor }
      connection
    end
    RecordingStudioOauth.stub(:connection_for, lookup) do
      yield calls
    end
  end
end
