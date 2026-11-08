# Capturers: one class per capture method, in app/services/capturers/. Each takes a Capture and a
# work directory, writes files into that directory, and returns the artifacts to store.
# CaptureJob runs them. Capturers::Router picks them from a URL.
#
# Every external tool runs through Capturers::Subprocess: a clean environment, the URL as an
# argument (never a shell string), a timeout and an output cap. A capturer never runs code from
# the archived content.
module Capturers
  class Error < StandardError; end
  # The method does not apply to this URL after all. The capture becomes `skipped`.
  class Skip < Error; end
  # The tool ran past CAPTURE_TIMEOUT.
  class Timeout < Error; end
  # The output passed CAPTURE_MAX_BYTES.
  class TooLarge < Error; end
  # The tool exited with an error.
  class ToolFailed < Error; end

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
