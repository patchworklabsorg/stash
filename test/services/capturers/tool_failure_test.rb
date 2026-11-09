require "test_helper"

# A tool that exits with an error becomes NotPublic or NotFound when its output says why, and
# stays ToolFailed otherwise. The subprocess is stubbed: nothing runs.
class Capturers::ToolFailureTest < ActiveSupport::TestCase
  setup do
    @workdir = Dir.mktmpdir
    archive = create_archive(url: "https://github.com/someone/secret")
    @capture = archive.captures.create!(method_name: "git", status: "running", position: 0)
  end

  teardown do
    FileUtils.rm_rf(@workdir)
  end

  # Subprocess.run that answers the given lines as the tool's output and exits 128. The
  # classification reads that output, not the log, so the URL on the command line never counts.
  def failing_run(_capture, *lines)
    status = Struct.new(:exitstatus) { def success? = false }.new(128)
    lambda do |*_command, **_options|
      Capturers::Subprocess::Result.new(status: status, output: lines.join("\n"))
    end
  end

  test "the URL on the command line does not decide the code" do
    archive = create_archive(url: "https://github.com/someone/private-404-login")
    capture = archive.captures.create!(method_name: "git", status: "running", position: 0)

    stub_method(Capturers::Subprocess, :run, failing_run(capture, "fatal: the remote end hung up unexpectedly")) do
      assert_raises(Capturers::ToolFailed) { Capturers::Git.new(capture, @workdir).call }
    end
    assert_includes capture.log, "private-404-login", "the command line is logged"
  end

  test "git clone of a private repository is not_public" do
    error = stub_method(Capturers::Subprocess, :run, failing_run(@capture, "fatal: could not read Username for 'https://github.com': terminal prompts disabled")) do
      assert_raises(Capturers::NotPublic) { Capturers::Git.new(@capture, @workdir).call }
    end

    assert_includes error.message, "git clone: the source is private or needs a sign-in"
    assert_includes error.message, "exited with status 128"
  end

  test "git clone of a missing repository is not_found" do
    error = stub_method(Capturers::Subprocess, :run, failing_run(@capture, "fatal: repository 'https://example.org/x/y' not found")) do
      assert_raises(Capturers::NotFound) { Capturers::Git.new(@capture, @workdir).call }
    end

    assert_includes error.message, "the source is gone or the URL is wrong"
  end

  test "any other clone failure stays tool_failed" do
    stub_method(Capturers::Subprocess, :run, failing_run(@capture, "fatal: the remote end hung up unexpectedly")) do
      assert_raises(Capturers::ToolFailed) { Capturers::Git.new(@capture, @workdir).call }
    end
  end

  test "yt-dlp on a private video is not_public" do
    archive = create_archive(url: "https://www.youtube.com/watch?v=abcdefghijk")
    capture = archive.captures.create!(method_name: "video", status: "running", position: 0)

    stub_method(Capturers::Subprocess, :run, failing_run(capture, "ERROR: [youtube] abcdefghijk: Private video. Sign in if you've been granted access to this video")) do
      assert_raises(Capturers::NotPublic) { Capturers::Video.new(capture, @workdir).call }
    end
  end
end
