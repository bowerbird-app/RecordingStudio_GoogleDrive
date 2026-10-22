Rails.application.routes.draw do
  devise_for :users

  get "/recording_studio", to: redirect("/"), as: nil
  mount RecordingStudio::Engine, at: "/recording_studio"
  mount RecordingStudioAccessible::Engine, at: "/recording_studio_accessible"
  mount RecordingStudioAccessible::Engine, at: "/admin/access", as: :recording_studio_admin_access
  mount RecordingStudioApi::Engine, at: "/recording_studio_api"
  mount RecordingStudioOauth::Engine, at: "/recording_studio_oauth"
  mount RecordingStudioAttachable::Engine, at: "/recording_studio_attachable"
  mount RecordingStudioSiteSettings::Engine, at: "/recording_studio_site_settings"
  mount RecordingStudioRootSwitchable::Engine, at: "/recording_studio_root_switchable"

  RecordingStudioOauth::ProtectedResourceRegistry.draw_origin_well_known(self)

  recording_studio_admin_for :admin, at: "/admin", root_section: :root

  get "up" => "rails/health#show", as: :rails_health_check

  get "docs/install", to: "docs#install", as: :docs_install
  get "docs/config", to: "docs#configuration", as: :docs_config

  get "fake_oauth/authorize", to: "fake_oauth#authorize"
  post "fake_oauth/token", to: "fake_oauth#token"
  post "fake_oauth/revoke", to: "fake_oauth#revoke"

  root "home#index"
end
