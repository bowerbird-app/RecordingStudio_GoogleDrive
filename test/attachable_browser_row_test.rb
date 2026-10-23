# frozen_string_literal: true

require "test_helper"
require "recording_studio_google_drive/attachable/browser_row"
require "recording_studio_google_drive/attachable/browser_location"

class AttachableBrowserRowTest < Minitest::Test
  def test_file_row_uses_content_type_and_file_kind
    file = RecordingStudioGoogleDrive::DriveFile.new(
      id: "file-1",
      name: "Brief.pdf",
      mime_type: "application/pdf",
      size: 12,
      modified_at: nil,
      web_view_link: "https://drive.test/file-1",
      resource_key: nil
    )

    row = RecordingStudioGoogleDrive::Attachable::BrowserRow.from_drive_file(file)

    assert_equal :file, row[:kind]
    assert_equal "application/pdf", row[:content_type]
    refute row.key?(:mimeType)
    refute row.key?("mimeType")
  end

  def test_folder_row_uses_folder_kind_and_open_url
    folder = RecordingStudioGoogleDrive::DriveFile.new(
      id: "folder-1",
      name: "Briefs",
      mime_type: RecordingStudioGoogleDrive::FOLDER_MIME_TYPE,
      size: nil,
      modified_at: nil,
      web_view_link: nil,
      resource_key: nil
    )

    row = RecordingStudioGoogleDrive::Attachable::BrowserRow.from_drive_file(
      folder,
      open_url: "/google_drive/recordings/1/imports?folder_ids[]=folder-1"
    )

    assert_equal :folder, row[:kind]
    assert_equal "/google_drive/recordings/1/imports?folder_ids[]=folder-1", row[:open_url]
    refute row.key?(:content_type)
    refute row.key?(:mimeType)
  end

  def test_browser_location_builds_crumbs_and_parent_url
    location = RecordingStudioGoogleDrive::Attachable::BrowserLocation.new(
      folder_ids: %w[a b],
      folder_names: %w[Alpha Beta],
      query: nil,
      root_name: "Google Drive",
      url_builder: ->(ids:, names:) { "#{ids.join('/')}:#{names.join('/')}" }
    )

    assert_equal "b", location.current_folder_id
    assert_equal "a:Alpha", location.parent_url
    assert_equal "a/b/c:Alpha/Beta/Gamma", location.open_folder_url(folder_file("c", "Gamma"))
    path = location.current_path
    assert_equal "Google Drive", path.first[:name]
    assert_equal "Beta", path.last[:name]
    refute location.query_params.key?(:query)
    assert_equal %w[a b], location.query_params[:folder_ids]

    client = Object.new
    captured = nil
    client.define_singleton_method(:list) do |**kwargs|
      captured = kwargs
      RecordingStudioGoogleDrive::Page.new(entries: [], next_cursor: nil)
    end
    location.fetch_page(client: client, cursor: "n", page_size: 10)
    assert_equal "b", captured[:parent_id]
    assert_equal "n", captured[:cursor]
  end

  private

  def folder_file(id, name)
    RecordingStudioGoogleDrive::DriveFile.new(
      id: id,
      name: name,
      mime_type: RecordingStudioGoogleDrive::FOLDER_MIME_TYPE,
      size: nil,
      modified_at: nil,
      web_view_link: nil,
      resource_key: nil
    )
  end
end
