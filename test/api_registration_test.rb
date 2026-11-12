# frozen_string_literal: true

require "test_helper"
require "recording_studio_api"
require "recording_studio_attachable"

class ApiRegistrationTest < Minitest::Test
  FakeEndpoint = Struct.new(
    :name,
    :api,
    :http_verb,
    :path,
    :handler,
    :openapi,
    :input_contract,
    keyword_init: true
  )

  def test_registration_is_a_noop_without_recording_studio_api
    RecordingStudioGoogleDrive::Api.stub(:recording_studio_api_available?, false) do
      assert_nil RecordingStudioGoogleDrive::Api.register!
    end
  end

  def test_gemspec_omits_recording_studio_api_runtime_dependency
    gemspec = File.read(File.expand_path("../recording_studio_google_drive.gemspec", __dir__))

    refute_includes gemspec, '"recording_studio_api"'
  end

  def test_engine_registers_api_in_to_prepare
    engine = File.read(File.expand_path("../lib/recording_studio_google_drive/engine.rb", __dir__))

    assert_includes engine, 'initializer "recording_studio_google_drive.api"'
    assert_includes engine, "config.to_prepare { RecordingStudioGoogleDrive::Api.register! }"
  end

  def test_registers_list_search_and_import
    endpoints = capture_registrations { RecordingStudioGoogleDrive::Api.register! }

    names = endpoints.map { |endpoint| endpoint.name.to_s }
    assert_equal %w[google_drive.import google_drive.list google_drive.search], names
    assert(endpoints.all? { |endpoint| endpoint.api == :public })

    import, list, search = endpoints
    assert_equal :post, import.http_verb
    assert_equal "google_drive/import", import.path
    assert_equal RecordingStudioGoogleDrive::Api::Import, import.handler
    assert_equal "Google Drive - Import", import.openapi.fetch(:title)
    assert_equal "Google Drive - Import", import.openapi.fetch(:summary)
    assert import.input_contract.dig(:fields, :attachments, :required)

    assert_equal :get, list.http_verb
    assert_equal "google_drive/list", list.path
    assert_equal RecordingStudioGoogleDrive::Api::List, list.handler
    assert_equal "Google Drive - List", list.openapi.fetch(:title)
    assert_equal "Google Drive - List", list.openapi.fetch(:summary)

    assert_equal :get, search.http_verb
    assert_equal "google_drive/search", search.path
    assert_equal RecordingStudioGoogleDrive::Api::Search, search.handler
    assert_equal "Google Drive - Search", search.openapi.fetch(:title)
    assert_equal "Google Drive - Search", search.openapi.fetch(:summary)
    assert search.input_contract.dig(:fields, :query, :required)
  end

  def test_excluded_operations_are_not_registered
    endpoints = capture_registrations { RecordingStudioGoogleDrive::Api.register! }
    names = endpoints.map { |endpoint| endpoint.name.to_s }
    paths = endpoints.map(&:path)

    excluded_names = %w[
      picker_access_token google_drive.connect google_drive.disconnect
      google_drive.fetch_file google_drive.download google_drive.upload_file
    ]
    excluded_names.each { |name| refute_includes names, name }

    %w[picker connect download upload_file].each do |fragment|
      refute(paths.any? { |path| path.include?(fragment) })
    end
  end

  def test_register_is_idempotent
    endpoints = capture_registrations do
      assert RecordingStudioGoogleDrive::Api.register!
      assert RecordingStudioGoogleDrive::Api.register!
    end
    assert_equal 3, endpoints.size
  end

  private

  def capture_registrations(&block)
    captured = []
    register = lambda do |name, **options|
      captured << FakeEndpoint.new(name: name, **options.slice(*FakeEndpoint.members))
    end
    lookup = lambda do |name, api: :public|
      captured.find { |endpoint| endpoint.name == name && endpoint.api == api }
    end

    RecordingStudioApi.stub(:registered_endpoint, lookup) do
      RecordingStudioApi.stub(:register_endpoint, register, &block)
    end
    captured
  end
end
