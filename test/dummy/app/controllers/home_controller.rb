# frozen_string_literal: true

class HomeController < ApplicationController
  def index
    @drive_connection = drive_connection
    @drive_ready = drive_ready?
    @upload_recording = demo_page_recording
  end

  private

  def drive_connection
    return if current_user.nil?

    # Dummy-only home status. This is not the Drive API.
    RecordingStudioOauth::OutboundConnection.live.for_provider(provider_key).find_by(owner_actor: current_user)
  end

  def drive_ready?
    return false if current_user.nil? || demo_root_recording.nil?

    RecordingStudioOauth.connection_for(
      provider: provider_key,
      root: demo_root_recording,
      actor: current_user
    ).present?
  end

  def demo_root_recording
    workspace = Workspace.order(:name).first
    return if workspace.nil?

    RecordingStudio.root_recording_for(workspace)
  end

  def demo_page_recording
    page = Page.order(:title).first
    return if page.nil?

    RecordingStudio::Recording.find_by(recordable: page)
  end

  def provider_key
    RecordingStudioGoogleDrive.configuration.oauth_provider_key
  end
end
