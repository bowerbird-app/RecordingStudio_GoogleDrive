# frozen_string_literal: true

require "test_helper"
require "net/http"
require "webmock/minitest"

class HttpTransportTest < Minitest::Test
  def setup
    WebMock.enable!
    WebMock.disable_net_connect!
    WebMock.reset!
  end

  def teardown
    WebMock.reset!
    WebMock.allow_net_connect!
  end

  def test_post_redirect_without_location_raises_request_error
    stub_request(:post, json_uri).to_return(status: 302, body: "moved")

    error = assert_raises(RecordingStudioGoogleDrive::RequestError) do
      transport.post(json_uri, Net::HTTP::Post.new(json_uri), follow_cross_host: false)
    end

    assert_includes error.message, "refused a redirect"
  end

  def test_post_redirect_with_location_raises_request_error
    stub_request(:post, json_uri)
      .to_return(status: 302, headers: { "Location" => "https://www.googleapis.com/drive/v3/files/other" })

    error = assert_raises(RecordingStudioGoogleDrive::RequestError) do
      transport.post(json_uri, Net::HTTP::Post.new(json_uri), follow_cross_host: false)
    end

    assert_includes error.message, "refused a redirect"
  end

  def test_get_redirect_with_empty_location_returns_the_response
    stub_request(:get, json_uri).to_return(status: 302, body: "moved")

    response = transport.get(json_uri, follow_cross_host: false)

    assert_kind_of Net::HTTPRedirection, response
    assert_equal "moved", response.body
  end

  def test_get_bytes_caps_body_on_redirect_with_empty_location
    stub_request(:get, media_uri).to_return(status: 302, body: "x" * 20)

    error = assert_raises(ArgumentError) do
      transport.get_bytes(media_uri, follow_cross_host: true, max_bytes: 10)
    end

    assert_equal RecordingStudioGoogleDrive::Http::ByteCap::OVERSIZE, error.message
  end

  private

  def transport
    RecordingStudioGoogleDrive::Http::Transport.new(access_token: "access-token")
  end

  def json_uri
    URI("https://www.googleapis.com/drive/v3/files")
  end

  def media_uri
    URI("https://lh3.googleusercontent.com/download/abc")
  end
end
