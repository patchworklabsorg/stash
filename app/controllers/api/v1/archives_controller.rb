module Api
  module V1
    # The archive API for patch apps. See docs/api.md for the contract.
    #
    #   POST /api/v1/archives            archive a URL
    #   GET  /api/v1/archives/:id        one archive, with its captures and artifacts
    #   GET  /api/v1/archives?url=...    the archives of a URL, newest first
    #
    # A POST with a `reference.submission` is idempotent per client: a second POST with the same
    # submission and the same normalized URL returns the first archive with 200.
    class ArchivesController < BaseController
      MAX_BODY_BYTES = 16.kilobytes

      def index
        url = params[:url].to_s
        return render json: { error: "url_required" }, status: :unprocessable_content if url.blank?

        archives = Archive.for_url(url).recent.includes(captures: { artifacts: { file_attachment: :blob } }).limit(50)
        render json: { archives: archives.map { |a| ArchiveSerializer.new(a).as_json } }
      end

      def show
        archive = Archive.includes(captures: { artifacts: { file_attachment: :blob } }).find_by_public_id!(params[:id])
        render json: ArchiveSerializer.new(archive).as_json
      end

      def create
        if request.content_length.to_i > MAX_BODY_BYTES
          return render json: { error: "payload_too_large" }, status: :content_too_large
        end

        body = parse_body
        reference = body["reference"].is_a?(Hash) ? body["reference"] : {}
        archive = Archive.new(url: body["url"].to_s, note: body["note"].to_s.presence, reference: reference,
          client_id: current_client_id)

        existing = existing_for(archive)
        return render json: ArchiveSerializer.new(existing).as_json, status: :ok if existing

        if archive.save
          ArchiveJob.perform_later(archive)
          render json: ArchiveSerializer.new(archive).as_json, status: :created
        else
          render json: { error: "invalid", details: archive.errors.full_messages }, status: :unprocessable_content
        end
      rescue ActiveRecord::RecordNotUnique
        existing = existing_for(archive)
        render json: ArchiveSerializer.new(existing).as_json, status: :ok
      end

      private

      def existing_for(archive)
        archive.valid?
        return nil if archive.submission_ref.blank? || archive.normalized_url.blank?

        Archive.find_by(client_id: current_client_id, submission_ref: archive.submission_ref, normalized_url: archive.normalized_url)
      end

      def parse_body
        value = JSON.parse(request.raw_post.to_s)
        value.is_a?(Hash) ? value : {}
      rescue JSON::ParserError
        {}
      end
    end
  end
end
