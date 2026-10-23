# frozen_string_literal: true

module RecordingStudioGoogleDrive
  module Attachable
    module ImportsErrors
      private

      def handle_index_drive_error(error)
        return render_disconnected(reconnect: true) if Attachable.reconnect_error?(error)
        raise unless Integration.request_error?(error)

        @query = params[:query].to_s.strip
        @files = []
        @next_page_token = nil
        assign_browser_location
        flash.now[:alert] = error.message
        render :index, status: :bad_gateway
      end

      def handle_create_drive_error(error)
        return respond_to_reconnect_error if Attachable.reconnect_error?(error)
        return respond_to_request_error(error) if error.is_a?(ArgumentError)
        raise unless Integration.request_error?(error)

        respond_to_request_error(error)
      end

      def respond_to_request_error(error)
        respond_to do |format|
          format.json { render json: { error: error.message }, status: :unprocessable_content }
          format.html do
            redirect_to google_drive.recording_imports_path(@recording, browse_query), alert: error.message
          end
        end
      end

      def respond_to_reconnect_error
        respond_to do |format|
          format.json { render json: reconnect_json, status: :unauthorized }
          format.html { render_disconnected(reconnect: true) }
        end
      end

      def reconnect_json
        { error: reconnect_message }.merge(provider_connect_payload(needs_auth: true, reconnect: true))
      end

      def reconnect_message
        I18n.t(
          "recording_studio.google_drive.reconnect_to_continue",
          provider: provider_label,
          default: "Reconnect #{provider_label} to continue"
        )
      end
    end
  end
end
