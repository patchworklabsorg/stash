# Capturers: one class per capture method, in app/services/capturers/. Each takes a Capture and a
# work directory, writes files into that directory, and returns the artifacts to store.
# CaptureJob runs them. Capturers::Router picks them from a URL.
#
# Every external tool runs through Capturers::Subprocess: a clean environment, the URL as an
# argument (never a shell string), a timeout and an output cap. A capturer never runs code from
# the archived content.
module Capturers
  # A capture that cannot finish raises one of these. The class is the reason, in a form a
  # patch app can act on: `code` goes into `captures.error_code` and into the API, the message
  # into `captures.error`. Capturers.hint(code) is the sentence for the person who can fix it.
  class Error < StandardError
    # The HTTP status that caused it, when one did.
    attr_accessor :http_status

    def self.code
      name.demodulize.underscore
    end

    def code
      self.class.code
    end
  end

  # The method does not apply to this URL after all. The capture becomes `skipped`.
  class Skip < Error; end
  # The tool ran past CAPTURE_TIMEOUT.
  class Timeout < Error; end
  # The output passed CAPTURE_MAX_BYTES.
  class TooLarge < Error; end
  # The tool exited with an error, and nothing more specific is known.
  class ToolFailed < Error; end
  # The source needs a sign-in or a share: a private repository, a Google document that is not
  # shared with anyone with the link, a private video. The owner can fix it.
  class NotPublic < Error; end
  # Nothing is at the URL: 404 or 410, a deleted video, a repository that is gone.
  class NotFound < Error; end
  # The host refused the archiver: 403, 429, an anti-bot wall. Later may work.
  class Blocked < Error; end

  # The error codes a capture can carry, in the order that matters most to the person who
  # submitted the URL. Archive#problem picks the first one present.
  CODES = %w[not_public not_found blocked too_large timeout tool_failed unexpected].freeze

  HINTS = {
    "not_public" => "The source is private. Ask the owner to share it with anyone with the link, or to send a public URL, then run the archive again.",
    "not_found" => "Nothing is at that URL. Ask for the right link, then run the archive again.",
    "blocked" => "The site refused the archiver. Run the archive again later.",
    "too_large" => "The file is larger than the size limit.",
    "timeout" => "The capture ran out of time. Run the archive again.",
    "tool_failed" => "The capture tool failed. Run the archive again. If it fails the same way, it is a Stash problem.",
    "unexpected" => "Stash hit an unexpected error. Run the archive again. If it fails the same way, it is a Stash problem."
  }.freeze

  # One sentence for a person, for a code. Unknown codes get the generic one.
  def self.hint(code)
    HINTS.fetch(code.to_s, HINTS["tool_failed"])
  end

  # Builds the error for an HTTP status: 401 needs a sign-in, 403 and 429 are a refusal, 404 and
  # 410 mean gone, anything else is a plain failure.
  def self.http_error(status, message)
    klass =
      case status.to_i
      when 401 then NotPublic
      when 403, 429 then Blocked
      when 404, 410 then NotFound
      else ToolFailed
      end
    error = klass.new(message)
    error.http_status = status.to_i
    error
  end

  # One file for CaptureJob to store. `path` is inside the work directory.
  Output = Data.define(:role, :path, :filename, :content_type)

  # Limits, read from the environment each time so tests can change them.
  def self.timeout
    ENV.fetch("CAPTURE_TIMEOUT", 600).to_i.seconds
  end

  def self.max_bytes
    ENV.fetch("CAPTURE_MAX_BYTES", 2.gigabytes).to_i
  end
end
