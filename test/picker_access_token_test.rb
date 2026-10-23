# frozen_string_literal: true

require "test_helper"

class PickerAccessTokenTest < Minitest::Test
  FakeConnection = Struct.new(:access_token)

  def setup
    @root = Object.new
    @actor = Object.new
  end

  def test_returns_the_current_access_token
    with_connection(FakeConnection.new("ya29.picker")) do |calls|
      token = RecordingStudioGoogleDrive.picker_access_token(root: @root, actor: @actor)

      assert_equal "ya29.picker", token
      assert_equal [{ provider: :google_drive, root: @root, actor: @actor }], calls
    end
  end

  def test_no_connection_raises_reconnect_required
    with_connection(nil) do
      error = assert_raises(RecordingStudioGoogleDrive::ReconnectRequired) do
        RecordingStudioGoogleDrive.picker_access_token(root: @root, actor: @actor)
      end

      assert_equal "Google Drive needs connecting again", error.message
    end
  end

  def test_needs_reconnect_raises_reconnect_required
    with_connection(nil) do
      error = assert_raises(RecordingStudioGoogleDrive::ReconnectRequired) do
        RecordingStudioGoogleDrive.picker_access_token(root: @root, actor: @actor)
      end

      assert_kind_of RecordingStudioGoogleDrive::ReconnectRequired, error
    end
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
