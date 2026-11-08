# One stored file from a capture, in Active Storage.
#
# Roles:
#   original    the thing itself: the MHTML, the git bundle, the .pptx, the media file
#   rendition   a derived copy in a viewable form: the print PDF of a page, the PDF of a deck
#   screenshot  a PNG of the page or a poster of a video
#   metadata    JSON or text about the thing: repo metadata, refs, yt-dlp info, a normalized post
class Artifact < CentralRecord
  # The prefix "art" is registered in internal-docs (encoded-id-prefixes.md).
  include EncodedIds::UuidIdentifiable
  set_public_id_prefix "art"

  ROLES = %w[original rendition screenshot metadata].freeze

  belongs_to :capture, inverse_of: :artifacts
  has_one :archive, through: :capture
  has_one_attached :file

  validates :role, inclusion: { in: ROLES }
  validates :filename, presence: true, length: { maximum: 255 }
  validates :content_type, presence: true
  validates :byte_size, numericality: { only_integer: true, greater_than_or_equal_to: 0 }
  validates :sha256, format: { with: /\A[0-9a-f]{64}\z/ }

  def image?
    content_type.start_with?("image/")
  end

  def pdf?
    content_type == "application/pdf"
  end

  def text?
    content_type.start_with?("text/") || content_type == "application/json"
  end
end
