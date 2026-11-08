# The archive list, one archive's page, the "archive a URL" form (archivist), "run again"
# (archivist) and delete (admin, with a reason). ArchivePolicy holds the rules.
class ArchivesController < ApplicationController
  before_action :set_archive, only: %i[show rerun destroy]

  def index
    @term = params[:q].to_s
    @archives = policy_scope(Archive).recent.matching(@term).includes(:captures).page(params[:page])
  end

  def show
    authorize @archive
    @captures = @archive.captures.includes(artifacts: { file_attachment: :blob })
  end

  def new
    @archive = Archive.new
    authorize @archive
  end

  def create
    @archive = Archive.new(archive_params.merge(requested_by_sub: current_user.sub))
    authorize @archive
    if @archive.save
      ArchiveJob.perform_later(@archive)
      redirect_to @archive, notice: "Archiving #{@archive.url}."
    else
      render :new, status: :unprocessable_content
    end
  end

  # Runs every capture of the archive again. Old artifacts stay until the new ones are stored.
  def rerun
    authorize @archive
    Archive.transaction do
      @archive.captures.destroy_all
      @archive.update!(status: "queued", completed_at: nil)
      AuditEvent.create!(actor_sub: current_user.sub, action: "archive.rerun", subject_type: "Archive",
        subject_public_id: @archive.public_id, reason: "run again from the archive page")
    end
    ArchiveJob.perform_later(@archive)
    redirect_to @archive, notice: "Archiving again."
  end

  def destroy
    authorize @archive
    reason = params[:reason].to_s.strip
    if reason.blank?
      return redirect_to @archive, alert: "Give a reason to delete an archive."
    end

    Archive.transaction do
      AuditEvent.create!(actor_sub: current_user.sub, action: "archive.deleted", subject_type: "Archive",
        subject_public_id: @archive.public_id, reason: reason,
        details: { "url" => @archive.url, "artifacts" => @archive.artifacts.map { |a| { "role" => a.role, "filename" => a.filename, "sha256" => a.sha256 } } })
      @archive.destroy!
    end
    redirect_to archives_path, notice: "Deleted the archive of #{@archive.url}."
  end

  private

  def set_archive
    @archive = Archive.find_by_public_id!(params[:id])
  end

  def archive_params
    params.require(:archive).permit(:url, :note)
  end
end
