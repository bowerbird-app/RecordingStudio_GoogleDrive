# frozen_string_literal: true

require "test_helper"
require "recording_studio_attachable"

unless defined?(RecordingStudioAttachable::Services::ImportRemoteFiles)
  module RecordingStudioAttachable
    module Services
      module ImportRemoteFiles
        def self.call(**)
          raise "ImportRemoteFiles.call must be stubbed in this test"
        end
      end
    end
  end
end

require "recording_studio_google_drive/attachable"

class AttachableRemoteImportTest < Minitest::Test
  DriveFile = Struct.new(:id, :name, :mime_type, :byte_size, :web_view_link, keyword_init: true) do
    def size
      byte_size
    end
  end
  Downloaded = Struct.new(:body, :filename, :content_type, keyword_init: true)

  def setup
    @captured = nil
    @client = fake_client
  end

  def test_blank_selection_returns_a_failed_result
    result = RecordingStudioGoogleDrive::Attachable::RemoteImport.call(
      parent_recording: Object.new,
      attachments: [],
      actor: Object.new
    )

    refute_predicate result, :success?
    assert_match(/select at least one/i, result.error)
  end

  def test_builds_import_payloads_from_picker_attachments
    parent = Object.new
    actor = Object.new
    impersonator = Object.new

    importer = lambda { |**kwargs|
      @captured = kwargs
      success_result
    }

    RecordingStudioGoogleDrive::Attachable::Integration.stub(:client, ->(**) { @client }) do
      RecordingStudioAttachable::Services::ImportRemoteFiles.stub(:call, importer) do
        result = RecordingStudioGoogleDrive::Attachable::RemoteImport.call(
          parent_recording: parent,
          attachments: [{ provider_payload: { "id" => "file-1", "resource_key" => "rk" } }],
          actor: actor,
          impersonator: impersonator
        )

        assert_predicate result, :success?
      end
    end

    assert_equal parent, @captured.fetch(:parent_recording)
    assert_equal :google_drive, @captured.fetch(:provider_key)
    assert_equal actor, @captured.fetch(:actor)
    assert_equal impersonator, @captured.fetch(:impersonator)

    payload = @captured.fetch(:payloads).first
    assert_equal "Brief.pdf", payload[:filename]
    assert_equal "Brief.pdf", payload[:name]
    assert_equal "Imported from Google Drive", payload[:description]
    assert_equal "file-1", payload[:metadata][:external_id]
    assert_equal "https://drive.test/file-1", payload[:metadata][:external_url]

    downloaded = payload[:download].call
    assert_equal "%PDF-1.4\nbrief", downloaded[:io].read
    assert_equal "Brief.pdf", downloaded[:filename]
    assert_equal "application/pdf", downloaded[:content_type]
    assert_equal 12, downloaded[:byte_size]
  end

  def test_rejects_files_over_attachable_max_size
    config = RecordingStudioAttachable.configuration
    original = config.max_file_size
    config.max_file_size = 10

    RecordingStudioGoogleDrive::Attachable::Integration.stub(:client, ->(**) { @client }) do
      error = assert_raises(ArgumentError) do
        RecordingStudioGoogleDrive::Attachable::RemoteImport.call(
          parent_recording: Object.new,
          attachments: [{ "id" => "file-1" }]
        )
      end

      assert_includes error.message, "maximum file size"
    end
  ensure
    config.max_file_size = original
  end

  def test_reconnect_required_from_fetch_is_not_swallowed
    client = Object.new
    client.define_singleton_method(:fetch_file) do |*_args, **|
      raise RecordingStudioGoogleDrive::ReconnectRequired, "expired"
    end

    RecordingStudioGoogleDrive::Attachable::Integration.stub(:client, ->(**) { client }) do
      error = assert_raises(RecordingStudioGoogleDrive::ReconnectRequired) do
        RecordingStudioGoogleDrive::Attachable::RemoteImport.call(
          parent_recording: Object.new,
          attachments: [{ provider_payload: { id: "file-1" } }]
        )
      end

      assert_equal "expired", error.message
    end
  end

  private

  def fake_client
    file = DriveFile.new(
      id: "file-1",
      name: "Brief.pdf",
      mime_type: "application/pdf",
      byte_size: 12,
      web_view_link: "https://drive.test/file-1"
    )
    downloaded = Downloaded.new(
      body: "%PDF-1.4\nbrief",
      filename: "Brief.pdf",
      content_type: "application/pdf"
    )
    client = Object.new
    client.define_singleton_method(:fetch_file) { |_id, **| file }
    client.define_singleton_method(:download) { |_id, **| downloaded }
    client
  end

  def success_result
    RecordingStudioAttachable::Services::BaseService::Result.new(success: true, value: [:ok])
  end
end
