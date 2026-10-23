# frozen_string_literal: true

require "test_helper"

class ContractTest < Minitest::Test
  MODULE = RecordingStudioGoogleDrive

  def test_error_classes
    assert_equal StandardError, MODULE::Error.superclass
    assert_equal MODULE::Error, MODULE::ReconnectRequired.superclass
    assert_equal MODULE::Error, MODULE::RequestError.superclass
    assert_equal(
      [%i[opt message], %i[key status], %i[key code]],
      MODULE::RequestError.instance_method(:initialize).parameters
    )
  end

  def test_request_error_status_and_code_readers
    error = MODULE::RequestError.new("boom", status: 500, code: "INTERNAL")
    assert_equal 500, error.status
    assert_equal "INTERNAL", error.code

    blank = MODULE::RequestError.new("boom")
    assert_nil blank.status
    assert_nil blank.code
  end

  def test_access_token_new_provider_and_to_s
    assert_equal [%i[req provider]], MODULE::AccessToken.instance_method(:initialize).parameters
    assert MODULE::AccessToken.method_defined?(:to_s)

    token = MODULE::AccessToken.new(-> { "ya29.live" })
    assert_equal "ya29.live", token.to_s
  end

  def test_access_token_prefers_call_over_access_token
    provider = Object.new
    provider.define_singleton_method(:call) { "from-call" }
    provider.define_singleton_method(:access_token) { "from-reader" }

    assert_equal "from-call", MODULE::AccessToken.new(provider).to_s
  end

  def test_access_token_uses_access_token_when_call_is_missing
    provider = Object.new
    provider.define_singleton_method(:access_token) { "from-reader" }

    assert_equal "from-reader", MODULE::AccessToken.new(provider).to_s
  end

  def test_string_provider_is_misconfiguration
    error = assert_raises(ArgumentError) { MODULE::AccessToken.new("ya29.raw") }
    assert_includes error.message, "call or access_token"
  end

  def test_provider_must_respond_to_call_or_access_token
    error = assert_raises(ArgumentError) { MODULE::AccessToken.new(Object.new) }
    assert_includes error.message, "call or access_token"
  end

  def test_blank_or_nil_token_requires_reconnect
    assert_raises(MODULE::ReconnectRequired) { MODULE::AccessToken.new(-> {}).to_s }
    assert_raises(MODULE::ReconnectRequired) { MODULE::AccessToken.new(-> { "  " }).to_s }
  end

  def test_page_entries_cursor_and_more
    assert_equal %i[entries next_cursor], MODULE::Page.members

    empty = MODULE::Page.new(entries: [], next_cursor: nil)
    assert_equal [], empty.entries
    assert_nil empty.next_cursor
    refute empty.more?

    blank = MODULE::Page.new(entries: [], next_cursor: "")
    refute blank.more?

    page = MODULE::Page.new(entries: [:file], next_cursor: "cursor-2")
    assert_equal [:file], page.entries
    assert_equal "cursor-2", page.next_cursor
    assert page.more?
  end

  def test_downloaded_file_body_filename_content_type
    assert_equal %i[body filename content_type], MODULE::DownloadedFile.members

    file = MODULE::DownloadedFile.new(body: "bytes", filename: "notes.pdf", content_type: "application/pdf")
    assert_equal "bytes", file.body
    assert_equal "notes.pdf", file.filename
    assert_equal "application/pdf", file.content_type

    untitled = MODULE::DownloadedFile.new(body: "bytes", filename: "notes.bin", content_type: nil)
    assert_nil untitled.content_type
    assert_raises(ArgumentError) { MODULE::DownloadedFile.new(body: "bytes", filename: "notes.bin") }
  end

  def test_list_and_search_take_cursor_and_page_size_keywords
    list = MODULE::Client.instance_method(:list)
    search = MODULE::Client.instance_method(:search)
    upload = MODULE::Client.instance_method(:upload_file)

    assert_equal [%i[key parent_id], %i[key cursor], %i[key page_size]], list.parameters
    assert_equal [%i[keyreq query], %i[key cursor], %i[key page_size]], search.parameters
    assert_equal(
      [%i[keyreq io], %i[keyreq filename], %i[keyreq content_type], %i[key parent_id]],
      upload.parameters
    )
    assert MODULE::Client.method_defined?(:download)
  end

  def test_picker_access_token_takes_root_and_actor
    method = MODULE.method(:picker_access_token)

    assert_equal [%i[keyreq root], %i[keyreq actor]], method.parameters
  end

  def test_configure_returns_the_configuration
    yielded = nil
    result = MODULE.configure { |config| yielded = config }

    assert_equal MODULE.configuration, result
    assert_equal MODULE.configuration, yielded
    assert_equal MODULE.configuration, MODULE.configure
  end
end
