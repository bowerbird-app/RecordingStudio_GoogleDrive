# frozen_string_literal: true

require "test_helper"
require "recording_studio_attachable"
require "recording_studio_google_drive/attachable"

class ApiAccessTest < Minitest::Test
  Context = Struct.new(:params, :access_grant, keyword_init: true)
  Recording = Struct.new(:id)
  Grant = Struct.new(:actor, :authorized) do
    def authorize!(recording:, role:)
      self.authorized = { recording: recording, role: role }
    end
  end

  def setup
    install_api_errors!
    @recording = Recording.new("rec-1")
    @actor = Object.new
    @grant = Grant.new(@actor)
    @context = Context.new(params: { recording_id: "rec-1" }, access_grant: @grant)
  end

  def teardown
    remove_api_errors!
  end

  def test_api_authorize_uses_attachable_upload_permission
    allowed_args = nil
    allow = lambda { |action:, actor:, recording:|
      allowed_args = { action: action, actor: actor, recording: recording }
      true
    }

    RecordingStudioGoogleDrive::Api::Access.stub(:recording_for, @recording) do
      RecordingStudioAttachable::Authorization.stub(:allowed?, allow) do
        assert RecordingStudioGoogleDrive::Api::Access.allowed?(@context)
      end
    end

    assert_equal({ action: :upload, actor: @actor, recording: @recording }, allowed_args)
  end

  def test_api_authorize_denies_when_upload_is_not_allowed
    RecordingStudioGoogleDrive::Api::Access.stub(:recording_for, @recording) do
      RecordingStudioAttachable::Authorization.stub(:allowed?, false) do
        refute RecordingStudioGoogleDrive::Api::Access.allowed?(@context)
      end
    end
  end

  def test_authorize_bang_denies_through_accessible_when_upload_is_refused
    RecordingStudioGoogleDrive::Api::Access.stub(:recording_for, @recording) do
      RecordingStudioAttachable::Authorization.stub(:allowed?, false) do
        error = assert_raises(RecordingStudioApi::AuthorizationError) do
          RecordingStudioGoogleDrive::Api::Access.authorize!(@context)
        end
        assert_equal RecordingStudioGoogleDrive::Api::Access::DENIED_MESSAGE, error.message
      end
    end

    assert_equal({ recording: @recording, role: :edit }, @grant.authorized)
  end

  def test_authorize_bang_returns_the_recording_when_upload_is_allowed
    RecordingStudioGoogleDrive::Api::Access.stub(:recording_for, @recording) do
      RecordingStudioAttachable::Authorization.stub(:allowed?, true) do
        assert_equal @recording, RecordingStudioGoogleDrive::Api::Access.authorize!(@context)
      end
    end

    assert_equal({ recording: @recording, role: :edit }, @grant.authorized)
  end

  def test_recording_for_skips_a_blank_id
    assert_nil RecordingStudioGoogleDrive::Api::Access.recording_for(Context.new(params: {}))
  end

  def test_client_for_uses_integration
    called = nil
    client = Object.new
    RecordingStudioGoogleDrive::Attachable::Integration.stub(:root_for, :root) do
      RecordingStudioGoogleDrive::Attachable::Integration.stub(:client, lambda { |**kwargs|
        called = kwargs
        client
      }) do
        assert_equal client, RecordingStudioGoogleDrive::Api::Access.client_for(@recording, @context)
      end
    end

    assert_equal({ root: :root, actor: @actor }, called)
  end

  def test_request_error_becomes_invalid_input
    error = assert_raises(RecordingStudioApi::InvalidActionInputError) do
      RecordingStudioGoogleDrive::Api::Access.raise_drive_error!(
        RecordingStudioGoogleDrive::RequestError.new("drive down", status: 503, code: "backendError")
      )
    end
    assert_equal "drive down", error.message
  end

  def test_missing_recording_is_not_found
    RecordingStudioGoogleDrive::Api::Access.stub(:recording_for, nil) do
      error = assert_raises(RecordingStudioApi::NotFoundError) do
        RecordingStudioGoogleDrive::Api::Access.authorize!(@context)
      end
      assert_equal "Recording was not found", error.message
    end
  end

  private

  def install_api_errors!
    return if defined?(RecordingStudioApi)

    api = Module.new
    api.const_set(:AuthorizationError, Class.new(StandardError))
    api.const_set(:NotFoundError, Class.new(StandardError))
    api.const_set(:InvalidActionInputError, Class.new(StandardError))
    Object.const_set(:RecordingStudioApi, api)
    @defined_api = true
  end

  def remove_api_errors!
    return unless @defined_api

    Object.send(:remove_const, :RecordingStudioApi)
    @defined_api = false
  end
end
