# frozen_string_literal: true

require "test_helper"
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

  def teardown
    remove_fake_api!
  end

  def test_registration_is_a_noop_without_recording_studio_api
    hide_real_api!
    refute Object.const_defined?(:RecordingStudioApi, false)
    assert_nil RecordingStudioGoogleDrive::Api.register!
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
    api = install_fake_api!

    assert RecordingStudioGoogleDrive::Api.register!

    names = api.endpoints.map { |endpoint| endpoint.name.to_s }
    assert_equal %w[google_drive.list google_drive.search google_drive.import], names
    assert(api.endpoints.all? { |endpoint| endpoint.api == :public })

    list, search, import = api.endpoints
    assert_equal :get, list.http_verb
    assert_equal "google_drive/list", list.path
    assert_equal RecordingStudioGoogleDrive::Api::List, list.handler
    assert_equal "Google Drive - List", list.openapi.fetch(:summary)

    assert_equal :get, search.http_verb
    assert_equal "google_drive/search", search.path
    assert_equal RecordingStudioGoogleDrive::Api::Search, search.handler
    assert_equal "Google Drive - Search", search.openapi.fetch(:summary)
    assert search.input_contract.dig(:fields, :query, :required)

    assert_equal :post, import.http_verb
    assert_equal "google_drive/import", import.path
    assert_equal RecordingStudioGoogleDrive::Api::Import, import.handler
    assert_equal "Google Drive - Import", import.openapi.fetch(:summary)
    assert import.input_contract.dig(:fields, :attachments, :required)
  end

  def test_excluded_operations_are_not_registered
    api = install_fake_api!
    RecordingStudioGoogleDrive::Api.register!

    names = api.endpoints.map { |endpoint| endpoint.name.to_s }
    paths = api.endpoints.map(&:path)

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
    api = install_fake_api!

    assert RecordingStudioGoogleDrive::Api.register!
    assert RecordingStudioGoogleDrive::Api.register!
    assert_equal 3, api.endpoints.size
  end

  private

  def install_fake_api!
    api = Module.new
    endpoints = []
    api.define_singleton_method(:endpoints) { endpoints }
    api.define_singleton_method(:register_endpoint) do |name, **options|
      endpoints << FakeEndpoint.new(name: name, **options.slice(*FakeEndpoint.members))
    end
    api.define_singleton_method(:registered_endpoint) do |name, api: :public|
      endpoints.find { |endpoint| endpoint.name == name && endpoint.api == api }
    end
    hide_real_api!
    Object.const_set(:RecordingStudioApi, api)
    api
  end

  def hide_real_api!
    return if @hidden_api
    return unless Object.const_defined?(:RecordingStudioApi, false)

    @hidden_api = Object.send(:remove_const, :RecordingStudioApi)
  end

  def remove_fake_api!
    Object.send(:remove_const, :RecordingStudioApi) if Object.const_defined?(:RecordingStudioApi, false)
    Object.const_set(:RecordingStudioApi, @hidden_api) if @hidden_api
    @hidden_api = nil
  end
end
