# frozen_string_literal: true

module RecordingStudioGoogleDrive
  module Attachable
    class ImportsController < ApplicationController
      include ImportsSupport

      def index
        authorize_provider_upload!
        ensure_provider_available!

        return render_disconnected unless google_drive_connected?

        load_drive_page
        render :index
      rescue RecordingStudioAttachable::DependencyUnavailableError => e
        dependency_unavailable_alert(e)
      rescue StandardError => e
        handle_index_drive_error(e)
      end

      def create
        authorize_provider_upload!
        ensure_provider_available!
        respond_to_import(import_selected)
      rescue RecordingStudioAttachable::DependencyUnavailableError => e
        respond_to_unavailable_create(e)
      rescue StandardError => e
        handle_create_drive_error(e)
      end

      private

      def import_selected
        RemoteImport.call(
          parent_recording: @recording,
          attachments: selected_attachments,
          actor: current_attachable_actor,
          impersonator: current_attachable_impersonator
        )
      end

      def respond_to_unavailable_create(error)
        respond_to do |format|
          format.json { render json: { error: error.message }, status: :unprocessable_content }
          format.html { dependency_unavailable_alert(error) }
        end
      end

      def respond_to_import(result)
        respond_to do |format|
          if result.success?
            format.json { render json: { redirect_path: success_redirect_path }, status: :created }
            format.html { respond_to_successful_html_import(result) }
          else
            format.json { render json: { error: result.error }, status: :unprocessable_content }
            format.html { redirect_to imports_path, alert: result.error }
          end
        end
      end

      def success_redirect_path
        resolved_attachment_redirect_path(@recording)
      end

      def imports_path
        google_drive.recording_imports_path(@recording, browse_query)
      end

      def respond_to_successful_html_import(result)
        return render_embedded_import if embedded_upload_provider_request?

        redirect_to success_redirect_path, notice: imported_notice(result)
      end

      def render_embedded_import
        render_upload_provider_modal_event(
          type: "provider-import-complete",
          provider_key: self.class.upload_provider_key.to_s,
          modal_id: current_upload_provider_modal_id,
          redirect_path: success_redirect_path
        )
      end

      def imported_notice(result)
        I18n.t(
          "recording_studio.google_drive.imported",
          count: result.value.size,
          default: "Imported #{result.value.size} files."
        )
      end
    end
  end
end
