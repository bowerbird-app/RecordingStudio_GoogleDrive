# frozen_string_literal: true

require "test_helper"
require "recording_studio_attachable"
require "recording_studio_google_drive/attachable"

class ApiOperationsTest < Minitest::Test
  Context = Struct.new(:params, :access_grant, keyword_init: true)
  Recording = Struct.new(:id)

  def setup
    install_api_errors!
    @recording = Recording.new("rec-1")
    @file = RecordingStudioGoogleDrive::DriveFile.new(
      id: "file-1",
      name: "Brief.pdf",
      mime_type: "application/pdf",
      size: 12,
      modified_at: nil,
      web_view_link: "https://drive.test/file-1",
      resource_key: nil
    )
    @page = RecordingStudioGoogleDrive::Page.new(entries: [@file], next_cursor: "cursor-2")
    @client = Object.new
  end

  def teardown
    remove_api_errors!
  end

  def test_list_authorizes_then_wraps_client_list
    listed = nil
    page = @page
    @client.define_singleton_method(:list) do |**kwargs|
      listed = kwargs
      page
    end

    result = with_authorized_client(@client) do
      RecordingStudioGoogleDrive::Api::List.call(
        Context.new(params: { recording_id: "rec-1", parent_id: "folder-1", cursor: "c1", page_size: 10 })
      )
    end

    assert_equal({ parent_id: "folder-1", cursor: "c1", page_size: 10 }, listed)
    assert_equal "file-1", result[:entries].first.fetch(:id)
    assert_equal "cursor-2", result[:next_cursor]
    assert_equal true, result[:more]
  end

  def test_search_authorizes_then_wraps_client_search
    searched = nil
    page = @page
    @client.define_singleton_method(:search) do |**kwargs|
      searched = kwargs
      page
    end

    result = with_authorized_client(@client) do
      RecordingStudioGoogleDrive::Api::Search.call(
        Context.new(params: { recording_id: "rec-1", query: "brief", parent_id: "folder-1" })
      )
    end

    assert_equal({ query: "brief", parent_id: "folder-1" }, searched)
    assert_equal "Brief.pdf", result[:entries].first.fetch(:name)
  end

  def test_import_authorizes_then_wraps_remote_import
    captured = nil
    imported = [Recording.new("att-1")]
    result_object = Struct.new(:success?, :value, :error, :errors).new(true, imported, nil, [])

    importer = lambda { |**kwargs|
      captured = kwargs
      result_object
    }

    payload = with_authorized_client(@client) do
      RecordingStudioGoogleDrive::Attachable::RemoteImport.stub(:call, importer) do
        RecordingStudioGoogleDrive::Api::Import.call(
          Context.new(
            params: { recording_id: "rec-1", attachments: [{ id: "file-1" }] },
            access_grant: Struct.new(:actor).new(:actor)
          )
        )
      end
    end

    assert_equal @recording, captured.fetch(:parent_recording)
    assert_equal [{ id: "file-1" }], captured.fetch(:attachments)
    assert_equal :actor, captured.fetch(:actor)
    assert_equal({ attachments: [{ id: "att-1" }] }, payload)
  end

  def test_unauthorized_list_is_denied
    grant = Object.new
    grant.define_singleton_method(:authorize!) { |**| raise RecordingStudioApi::AuthorizationError, "no" }

    error = assert_raises(RecordingStudioApi::AuthorizationError) do
      RecordingStudioGoogleDrive::Api::Access.stub(:recording_for, @recording) do
        RecordingStudioGoogleDrive::Api::List.call(Context.new(params: { recording_id: "rec-1" }, access_grant: grant))
      end
    end
    assert_equal "no", error.message
  end

  def test_import_maps_not_authorized_failure
    failure = Struct.new(:success?, :value, :error, :errors).new(false, nil, "Not authorized to upload", [])
    error = assert_raises(RecordingStudioApi::AuthorizationError) do
      with_authorized_client(@client) do
        RecordingStudioGoogleDrive::Attachable::RemoteImport.stub(:call, failure) do
          RecordingStudioGoogleDrive::Api::Import.call(
            Context.new(params: { recording_id: "rec-1", attachments: [{ id: "file-1" }] })
          )
        end
      end
    end
    assert_equal "Not authorized to upload", error.message
  end

  def test_import_maps_argument_error
    error = assert_raises(RecordingStudioApi::InvalidActionInputError) do
      with_authorized_client(@client) do
        importer = ->(**) { raise ArgumentError, "Select at least one file" }
        RecordingStudioGoogleDrive::Attachable::RemoteImport.stub(:call, importer) do
          RecordingStudioGoogleDrive::Api::Import.call(
            Context.new(params: { recording_id: "rec-1", attachments: [] })
          )
        end
      end
    end
    assert_equal "Select at least one file", error.message
  end

  def test_search_maps_request_error
    @client.define_singleton_method(:search) do |**|
      raise RecordingStudioGoogleDrive::RequestError.new("quota", status: 403, code: "quotaExceeded")
    end

    error = assert_raises(RecordingStudioApi::InvalidActionInputError) do
      with_authorized_client(@client) do
        RecordingStudioGoogleDrive::Api::Search.call(
          Context.new(params: { recording_id: "rec-1", query: "brief" })
        )
      end
    end
    assert_equal "quota", error.message
  end

  def test_reconnect_required_becomes_invalid_input
    @client.define_singleton_method(:list) do |**|
      raise RecordingStudioGoogleDrive::ReconnectRequired, "Google Drive needs connecting again"
    end

    error = assert_raises(RecordingStudioApi::InvalidActionInputError) do
      with_authorized_client(@client) do
        RecordingStudioGoogleDrive::Api::List.call(Context.new(params: { recording_id: "rec-1" }))
      end
    end
    assert_equal "Google Drive needs connecting again", error.message
  end

  private

  def with_authorized_client(client, &)
    RecordingStudioGoogleDrive::Api::Access.stub(:authorize!, @recording) do
      RecordingStudioGoogleDrive::Api::Access.stub(:client_for, client, &)
    end
  end

  def install_api_errors!
    return if defined?(RecordingStudioApi)

    api = Module.new
    api.const_set(:AuthorizationError, Class.new(StandardError))
    api.const_set(:NotFoundError, Class.new(StandardError))
    api.const_set(:InvalidActionInputError, Class.new(StandardError) do
      attr_reader :details

      def initialize(message = nil, details: [])
        super(message)
        @details = details
      end
    end)
    Object.const_set(:RecordingStudioApi, api)
    @defined_api = true
  end

  def remove_api_errors!
    return unless @defined_api

    Object.send(:remove_const, :RecordingStudioApi)
    @defined_api = false
  end
end
