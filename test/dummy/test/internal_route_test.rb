# frozen_string_literal: true

require "test_helper"

class InternalRouteTest < ActiveSupport::TestCase
  test "known app paths are internal" do
    assert internal_route?("/")
  end

  test "unrecognized paths are not internal" do
    refute internal_route?("/no-such-google-drive-dummy-path")
  end

  test "routing errors are treated as external" do
    missing = ->(*) { raise ActionController::RoutingError, "No route matches" }

    Rails.application.routes.stub(:recognize_path, missing) do
      RecordingStudioRootSwitchable::Engine.routes.stub(:recognize_path, missing) do
        refute internal_route?("/anything")
      end
    end
  end

  test "non-routing errors still raise" do
    broken = ->(*) { raise ArgumentError, "bad path" }

    error = assert_raises(ArgumentError) do
      Rails.application.routes.stub(:recognize_path, broken) do
        internal_route?("/anything")
      end
    end

    assert_equal "bad path", error.message
  end
end
