# frozen_string_literal: true

require "test_helper"

class RecordingStudioGoogleDriveTest < Minitest::Test
  def test_version_matches_release
    assert_equal "0.4.0", ::RecordingStudioGoogleDrive::VERSION
  end

  def test_engine_exists
    assert_kind_of Class, ::RecordingStudioGoogleDrive::Engine
  end

  def test_gemspec_pins_recording_studio_4_2
    gemspec = File.read(File.expand_path("../recording_studio_google_drive.gemspec", __dir__))

    gemfile = File.read(File.expand_path("../Gemfile", __dir__))

    assert_includes gemspec, 'spec.add_dependency "recording_studio", "~> 4.2"'
    assert_includes gemspec, 'spec.add_dependency "recording_studio_oauth", ">= 0.14.1", "< 1.0"'
    refute_includes gemspec, "recording_studio_attachable"
    assert_includes gemfile, "recording_studio_attachable"
    assert_includes gemfile, "900cc3a169e26f0e4604e1acb3cbc1d81281aa87"
    assert_includes gemspec, 'spec.required_ruby_version = ">= 3.3.0"'
  end

  def test_gemspec_excludes_cursor_config
    spec = Gem::Specification.load(File.expand_path("../recording_studio_google_drive.gemspec", __dir__))
    cursor_files = spec.files.select { |path| path == ".cursor" || path.split("/").include?(".cursor") }

    assert_empty cursor_files, "gemspec must not package .cursor/ (got #{cursor_files.inspect})"
  end

  def test_cursor_environment_is_repo_managed_without_snapshot
    path = File.expand_path("../.cursor/environment.json", __dir__)
    json = JSON.parse(File.read(path))

    assert_equal "recording-studio-google-drive", json["name"]
    assert_equal ".cursor/install.sh", json["install"]
    assert_equal ".cursor/start.sh", json["start"]
    refute json.key?("snapshot"), "snapshot pins a Personal build and skips install"
    refute json.key?("agentCanUpdateSnapshot")
  end

  def test_cursor_install_still_fetches_skills
    install_script = File.read(File.expand_path("../.cursor/install.sh", __dir__))

    assert_includes install_script, "fetch-skills.sh"
  end

  def test_dummy_gemfile_pins_verified_4x_github_tags
    gemfile = File.read(File.expand_path("dummy/Gemfile", __dir__))

    assert_includes gemfile, 'github: "bowerbird-app/RecordingStudio", tag: "v4.7.0"'
    refute_includes gemfile, 'tag: "v4.6.0"'
    refute_includes gemfile, 'tag: "v4.5.0"'
    assert_includes gemfile, 'github: "bowerbird-app/RecordingStudio_accessible", tag: "v0.18.0"'
    assert_includes gemfile, 'github: "bowerbird-app/RecordingStudio_trashable", tag: "v0.11.0", require: false'
    refute_includes gemfile, 'tag: "v0.10.0"'
    refute_includes gemfile, 'tag: "v0.17.0"'
    refute_includes gemfile, 'github: "bowerbird-app/RecordingStudio_accessible", tag: "v0.15.0"'
    refute_includes gemfile, 'tag: "v0.10.1"'
    assert_includes gemfile, 'github: "bowerbird-app/RecordingStudio_Oauth", tag: "v0.14.1"'
    assert_includes gemfile, 'github: "bowerbird-app/RecordingStudio_admin", tag: "v2.2.0"'
    assert_includes gemfile, 'github: "bowerbird-app/RecordingStudio_root_switchable", tag: "v0.9.0"'
    assert_includes gemfile, 'github: "bowerbird-app/RecordingStudio_cache", tag: "v0.5.0"'
    assert_includes gemfile, 'github: "bowerbird-app/RecordingStudio_metrics", tag: "v0.5.0"'
    assert_includes gemfile, 'github: "bowerbird-app/RecordingStudio_attachable",'
    assert_includes gemfile, 'ref: "900cc3a169e26f0e4604e1acb3cbc1d81281aa87"'
    assert_includes gemfile, 'github: "bowerbird-app/RecordingStudio_logs", tag: "v0.4.1"'
    assert_includes gemfile, 'github: "bowerbird-app/RecordingStudio_site_settings", tag: "v0.2.0"'
    assert_includes gemfile, 'github: "bowerbird-app/RecordingStudio_api", tag: "v0.14.0"'
    refute_includes gemfile, 'tag: "v0.6.0"'
    refute_includes gemfile, 'tag: "v0.5.1"'
    assert_includes gemfile, 'github: "bowerbird-app/flatpack", tag: "v0.1.213"'
    refute_includes gemfile, "recording_studio/v3.0.0"
    refute_includes gemfile, 'tag: "v4.4.0"'
    refute_includes gemfile, 'tag: "v4.3.0"'
    refute_includes gemfile, 'tag: "v4.2.2"'
    refute_includes gemfile, 'tag: "v4.2.1"'
    refute_includes gemfile, 'tag: "v4.2.0"'
    refute_includes gemfile, 'tag: "v0.9.1"'
    refute_includes gemfile, 'tag: "v0.8.0"'
    refute_includes gemfile, 'tag: "v0.1.177"'
    refute_includes gemfile, 'tag: "v0.1.133"'
    refute_includes gemfile, 'tag: "0.3.1"'
  end

  def test_dummy_schema_includes_accessible_depends_on_recording_id
    schema = File.read(File.expand_path("dummy/db/schema.rb", __dir__))
    migration = File.read(
      File.expand_path(
        "dummy/db/migrate/20260911024811_add_depends_on_recording_id_to_recording_studio_accesses.rb",
        __dir__
      )
    )

    assert_includes schema, 't.uuid "depends_on_recording_id"'
    assert_includes schema, "index_recording_studio_accesses_on_depends_on_recording_id"
    assert_includes migration, "add_column :recording_studio_accesses, :depends_on_recording_id, :uuid"
    assert_includes schema, 'create_table "recording_studio_access_invitations"'
    assert_includes schema, "idx_rs_access_invitations_token_digest"
    invitation_migration = File.read(
      File.expand_path(
        "dummy/db/migrate/20261001000011_create_recording_studio_access_invitations.rb",
        __dir__
      )
    )
    assert_includes invitation_migration, "create_table :recording_studio_access_invitations"
    assert_includes schema, 't.string "role", default: "view", null: false'
    refute_includes schema, 't.integer "role", default: 0, null: false'
    role_migration = Dir.glob(
      File.expand_path("dummy/db/migrate/*_change_recording_studio_accesses_role_to_string.rb", __dir__)
    ).max
    assert role_migration, "expected role-column migration in dummy db/migrate"
    assert_includes File.read(role_migration), "change_column :recording_studio_accesses, :role, :string"

    assert_includes schema, 'create_table "recording_studio_access_constraints"'
    assert_includes schema, 'create_table "recording_studio_access_rules"'
    assert_includes schema, 'create_table "recording_studio_oauth_outbound_connections"'
    assert_includes schema, 'create_table "active_storage_blobs"'
    assert_includes schema, 'create_table "admin_roots"'
    assert_includes schema, "index_recording_studio_access_constraints_on_action"
    assert_includes schema, "index_recording_studio_access_rules_on_action"
    constraint_migration = Dir.glob(
      File.expand_path("dummy/db/migrate/*_create_recording_studio_access_constraints.rb", __dir__)
    ).max
    rule_migration = Dir.glob(
      File.expand_path("dummy/db/migrate/*_create_recording_studio_access_rules.rb", __dir__)
    ).max
    assert constraint_migration, "expected access constraints migration in dummy db/migrate"
    assert rule_migration, "expected access rules migration in dummy db/migrate"
    assert_includes File.read(constraint_migration), "create_table :recording_studio_access_constraints"
    assert_includes File.read(rule_migration), "create_table :recording_studio_access_rules"
  end

  def test_template_does_not_ship_copied_core_hooks_or_base_service
    refute File.exist?(File.expand_path("../lib/recording_studio_google_drive/hooks.rb", __dir__))
    refute File.exist?(File.expand_path("../lib/recording_studio_google_drive/services/base_service.rb", __dir__))
    refute File.exist?(File.expand_path("../lib/recording_studio_google_drive/services/example_service.rb", __dir__))
  end

  def test_gem_does_not_ship_the_template_example_capability
    refute File.exist?(File.expand_path("../lib/recording_studio_google_drive/capabilities/example.rb", __dir__))
  end

  def test_dummy_app_uses_recording_studio_default_layout
    application_controller_path = File.expand_path("dummy/app/controllers/application_controller.rb", __dir__)
    controller_source = File.read(application_controller_path)

    assert_includes controller_source, "include RecordingStudio::UsesDefaultLayout"
    assert_includes controller_source, '"recording_studio/default_layout"'
    assert_includes controller_source, "devise_controller? ? \"application\""
    refute_includes controller_source, "flat_pack_sidebar"
    refute File.exist?(File.expand_path("dummy/app/views/layouts/flat_pack_sidebar.html.erb", __dir__))
    refute File.exist?(File.expand_path("dummy/app/views/layouts/flat_pack/_sidebar.html.erb", __dir__))
  end

  def test_dummy_login_layout_keeps_flatpack_assets_without_tight_main_offset
    application_layout = File.read(File.expand_path("dummy/app/views/layouts/application.html.erb", __dir__))

    assert_includes application_layout, '<html data-theme="rounded">'
    assert_includes application_layout, 'stylesheet_link_tag "flat_pack/variables"'
    assert_includes application_layout, 'stylesheet_link_tag "flat_pack/application"'
    assert_includes application_layout, 'stylesheet_link_tag "flat_pack/rich_text"'
    assert_includes application_layout, "javascript_importmap_tags"
    assert_includes application_layout, "min-h-screen"
    refute_includes application_layout, "mt-28"
    refute_includes application_layout, "flat_pack_sidebar"
  end

  def test_dummy_tailwind_keeps_flatpack_theme_selection_in_flatpack
    tailwind_source = File.read(File.expand_path("dummy/app/assets/tailwind/application.css", __dir__))

    assert_includes tailwind_source, "../../../vendor/engines/flat_pack/app/components"
    assert_includes tailwind_source, "../../../vendor/engines/recording_studio/app/views"
    assert_includes tailwind_source, "../../../vendor/engines/recording_studio_oauth/app/views"
    refute_includes tailwind_source, "vendor/bundle/**/flatpack/app/components"
    refute_includes tailwind_source, "recordingstudio-*"
    refute_includes tailwind_source, "@theme"
    refute_includes tailwind_source, ":root {"
    refute_includes tailwind_source, "--color-fp-primary"

    head_partial = File.read(
      File.expand_path("dummy/app/views/recording_studio/_default_layout_head.html.erb", __dir__)
    )
    assert_includes head_partial, 'stylesheet_link_tag "flat_pack/application"'

    rake_task = File.read(File.expand_path("dummy/lib/tasks/tailwindcss.rake", __dir__))
    assert_includes rake_task, "FlatPack::Engine.root"
    assert_includes rake_task, "RecordingStudio::Engine.root"
    assert_includes rake_task, "RecordingStudioOauth::Engine.root"
    assert_includes rake_task, "tailwindcss:link_engine_sources"
  end

  def test_recording_studio_keeps_strict_recordable_declarations_enabled
    initializer_path = File.expand_path("dummy/config/initializers/recording_studio.rb", __dir__)
    initializer_source = File.read(initializer_path)

    assert_includes initializer_source, "config.require_recordable_declarations = true"
    assert_includes initializer_source, '"Workspace"'
    assert_includes initializer_source, '"Folder"'
    assert_includes initializer_source, '"Page"'
    assert_includes initializer_source, '"AdminRoot"'
    assert_includes initializer_source, '"RecordingStudioAttachable::Attachment"'
    refute_includes initializer_source, "RecordingStudioAttachable::Library"
    refute_includes initializer_source, "RecordingStudioAttachable::Placement"
    refute_includes initializer_source, "config.include_children"
    refute_includes initializer_source, "config.features."
    refute_includes initializer_source, "v3"
  end

  def test_dummy_readme_explains_dummy_app_purpose
    readme_path = File.expand_path("dummy/README.md", __dir__)
    readme_source = File.read(readme_path)

    assert_includes readme_source, "This Rails app exists to validate the Recording Studio Google Drive addon"
    assert_includes readme_source, "/recording_studio"
    assert_includes readme_source, "redirects to `/`"
    refute_includes readme_source, "flat_pack_sidebar"
  end

  def test_product_readme_describes_the_drive_client
    readme = File.read(File.expand_path("../README.md", __dir__))

    assert_includes readme, "RecordingStudioGoogleDrive::Client"
    assert_includes readme, "token_provider"
    assert_includes readme, "connection_for"
    assert_includes readme, "Client.for"
    assert_includes readme, "picker_access_token"
    assert_includes readme, "Hand it to the Picker only"
    assert_includes readme, "recording_studio_oauth.outbound.google_drive"
    assert_includes readme, "client_id"
    assert_includes readme, "client_secret"
    assert_includes readme, "ReconnectRequired"
    assert_includes readme, "client.list"
    assert_includes readme, "client.search"
    assert_includes readme, "client.download"
    assert_includes readme, "upload_file"
    assert_includes readme, "Default page size is 25."
    assert_includes readme, "RecordingStudioAttachable"
    assert_includes readme, "config.attachable.enabled"
    assert_includes readme, "config.attachable.api_key"
    assert_includes readme, "register_upload_provider"
    assert_includes readme, "ProviderController"
    assert_includes readme, "ImportRemoteFiles"
    assert_includes readme, "ProviderConnect.payload"
    assert_includes readme, "recording_studio_attachable/provider_launchers"
    assert_includes readme, "/recording_studio_attachable/recordings/"
    refute_includes readme, "Template Demo"
    refute_includes readme, "ExampleService"
    refute_includes readme, "enable_feature_x"
  end

  def test_dummy_home_page_is_the_host_boot_screen
    view_path = File.expand_path("dummy/app/views/home/index.html.erb", __dir__)
    view_source = File.read(view_path)

    assert_includes view_source, 'title: "Google Drive"'
    assert_includes view_source, "Connect Google Drive"
    assert_includes view_source, "Disconnect"
    assert_includes view_source, "Reconnect"
    assert_includes view_source, "Upload to Getting Started"
    refute_includes view_source, "Template Demo"
    assert_includes view_source, "FlatPack::Card::Component"
    assert_includes view_source, "dummy_page_nav"
    refute_includes view_source, "FlatPack::Breadcrumb::Component"
    refute_includes view_source, "access_token"
  end

  def test_dummy_docs_pages_use_minimal_flatpack_documentation_components
    docs_view_paths = Dir[File.expand_path("dummy/app/views/docs/*.html.erb", __dir__)].reject do |view_path|
      File.basename(view_path).start_with?("_")
    end
    refute_empty docs_view_paths

    docs_view_paths.each do |view_path|
      view_source = File.read(view_path)

      assert_includes view_source, "dummy_page_nav"
      assert_includes view_source, "FlatPack::PageTitle::Component"
      refute_includes view_source, "FlatPack::Card::Component"
      refute_includes view_source, "FlatPack::Breadcrumb::Component"
    end

    %w[methods.html.erb gem_views.html.erb recordable_types.html.erb recordings_tree.html.erb].each do |view|
      refute File.exist?(File.expand_path("dummy/app/views/docs/#{view}", __dir__))
    end
    refute File.exist?(File.expand_path("dummy/app/views/docs/_recording_tree_node.html.erb", __dir__))
  end

  def test_engine_does_not_ship_a_home_view
    view_path = File.expand_path("../app/views/recording_studio_google_drive/home/index.html.erb", __dir__)
    controller_path = File.expand_path(
      "../app/controllers/recording_studio_google_drive/home_controller.rb",
      __dir__
    )

    refute File.exist?(view_path)
    refute File.exist?(controller_path)
    refute File.exist?(
      File.expand_path("../app/controllers/recording_studio_google_drive/application_controller.rb", __dir__)
    )
    refute File.exist?(File.expand_path("../app/views/recording_studio_google_drive/.keep", __dir__))
    refute File.exist?(File.expand_path("../.github/instructions/views.instructions.md", __dir__))
  end

  def test_dummy_app_name_is_google_drive_demo
    initializer = File.read(File.expand_path("dummy/config/initializers/recording_studio.rb", __dir__))

    assert_includes initializer, 'config.app_name = "Google Drive Demo"'
    refute_includes initializer, "Addon Template"
  end
end
