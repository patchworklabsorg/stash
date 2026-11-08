# Downloads one artifact. The file comes from Active Storage through a short-lived signed URL,
# so the storage service is never public. Inline for images and PDFs, a download for the rest.
class ArtifactsController < ApplicationController
  def show
    artifact = Artifact.includes(:capture).find_by_public_param!(params[:id])
    authorize artifact.archive, :show?
    disposition = artifact.image? || artifact.pdf? ? :inline : :attachment
    redirect_to artifact.file.url(expires_in: 10.minutes, disposition: disposition), allow_other_host: true
  end
end
