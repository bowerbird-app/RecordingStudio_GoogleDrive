module ApplicationHelper
  def drive_status_title
    return "Not connected" if @drive_connection.nil?
    return "Needs a reconnect" if @drive_connection.needs_reconnect? || !@drive_ready

    "Connected"
  end

  def drive_status_subtitle
    return "Plug Google Drive into this dummy. No real Google login." if @drive_connection.nil?
    return "The token went stale. Connect again and you are back." if @drive_connection.needs_reconnect? || !@drive_ready

    "Ready to list files. Disconnect whenever you like."
  end

  def drive_provider_key
    RecordingStudioGoogleDrive.configuration.oauth_provider_key
  end

  def dummy_page_nav(title:, back_url: nil, back_label: "Home")
    recording_studio_page_nav(
      title: title,
      page_nav_back_url: back_url,
      page_nav_back_label: back_label
    )

    recording_studio_page_nav_right do
      concat recording_studio_root_switch_dropdown(style: :ghost, size: :md)
      concat render(
        FlatPack::Button::Component.new(
          text: "Sign out",
          style: :ghost,
          size: :md,
          url: main_app.destroy_user_session_path,
          data: { turbo_method: :delete }
        )
      )
    end
  end
end
