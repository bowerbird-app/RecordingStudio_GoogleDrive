# frozen_string_literal: true

require "test_helper"
require "generators/recording_studio_google_drive/install/install_generator"

class InstallGeneratorTest < Minitest::Test
  INSTALL_TEMPLATE_PATH = File.expand_path(
    "../lib/generators/recording_studio_google_drive/install/templates/INSTALL.md",
    __dir__
  )

  def build_generator(destination_root, options = {})
    RecordingStudioGoogleDrive::Generators::InstallGenerator.new(
      [],
      options,
      destination_root: destination_root
    )
  end

  def test_generator_does_not_mount_engine_routes
    source = File.read(
      File.expand_path("../lib/generators/recording_studio_google_drive/install/install_generator.rb", __dir__)
    )

    refute_includes source, "mount_engine"
    refute_includes source, "add_tailwind_source"
    refute_includes source, "@source"
  end

  def test_show_readme_displays_install_guide_for_invoke_behavior
    generator = build_generator("/tmp")
    shown_templates = []

    generator.stub(:behavior, :invoke) do
      generator.stub(:readme, ->(template) { shown_templates << template }) do
        generator.show_readme
      end
    end

    assert_equal ["INSTALL.md"], shown_templates
  end

  def test_install_guide_describes_library_setup
    install_guide = File.read(INSTALL_TEMPLATE_PATH)

    assert_includes install_guide, "Client.for"
    assert_includes install_guide, "client_id"
    refute_includes install_guide, "tailwindcss:build"
    refute_includes install_guide, "Addon Template"
    refute File.exist?(
      File.expand_path("../lib/generators/recording_studio_google_drive/install/INSTALL.md", __dir__)
    )
  end
end
