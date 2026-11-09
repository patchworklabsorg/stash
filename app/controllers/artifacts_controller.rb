# Downloads one artifact. The file comes from Active Storage through a short-lived signed URL,
# so the storage service is never public. Inline for images and PDFs, a download for the rest.
#
# A `view` artifact (the page as one HTML file) also has a viewer: `view` is the Stash page
# around it, `frame` the document itself, served from Stash with a policy that lets it run
# nothing. The frame carries the archived page's own HTML, so it is treated as hostile: no
# scripts, no same-origin rights, no network except the data URLs the file holds.
class ArtifactsController < ApplicationController
  # What the archived document may do inside the frame. Styles and the inlined resources
  # (data URLs) render; scripts, fetches, forms, frames and every network request do not, so
  # the site under review never learns that someone opened the copy. A font or an image the
  # MHTML lacks falls back; the screenshot shows the page as it looked. `sandbox` without
  # `allow-same-origin` keeps it off Stash's origin and its cookies.
  FRAME_CSP = [
    "default-src 'none'",
    "img-src data:",
    "media-src data:",
    "font-src data:",
    "style-src 'unsafe-inline' data:",
    "form-action 'none'",
    "base-uri *",
    "sandbox allow-popups allow-popups-to-escape-sandbox"
  ].join("; ").freeze

  def show
    artifact = Artifact.includes(:capture).find_by_public_param!(params[:id])
    authorize artifact.archive, :show?
    disposition = artifact.image? || artifact.pdf? ? :inline : :attachment
    redirect_to artifact.file.url(expires_in: 10.minutes, disposition: disposition), allow_other_host: true
  end

  def view
    @artifact = viewable_artifact
    @archive = @artifact.archive
    # A parent's frame-src governs every navigation of its frames, the ones the frame starts
    # too, so whatever the rewrite missed, the frame cannot leave Stash.
    response.headers["Content-Security-Policy"] = "frame-src 'self'"
  end

  def frame
    artifact = viewable_artifact
    response.headers["Content-Security-Policy"] = FRAME_CSP
    response.headers["X-Frame-Options"] = "SAMEORIGIN"
    response.headers["Referrer-Policy"] = "no-referrer"
    response.headers["Cache-Control"] = "private, max-age=600"
    send_data artifact.file.download, type: "text/html; charset=utf-8", disposition: "inline"
  end

  private

  def viewable_artifact
    artifact = Artifact.includes(capture: :archive).find_by_public_param!(params[:id])
    authorize artifact.archive, :show?
    raise ActiveRecord::RecordNotFound unless artifact.view?

    artifact
  end
end
