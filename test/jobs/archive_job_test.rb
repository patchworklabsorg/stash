require "test_helper"

class ArchiveJobTest < ActiveJob::TestCase
  test "plans the captures from the URL and enqueues one job each" do
    archive = create_archive(url: "https://github.com/patchworklabsorg/stash")

    stub_method(Capturers::Download, :content_type, nil) do
      assert_enqueued_jobs 3, only: CaptureJob do
        ArchiveJob.perform_now(archive)
      end
    end

    assert_equal %w[github git page], archive.captures.map(&:method_name)
    assert_equal [ 0, 1, 2 ], archive.captures.map(&:position)
    assert_equal "repo", archive.reload.kind
  end

  test "uses the server's content type for a plain URL" do
    archive = create_archive(url: "https://example.org/download?id=1")

    stub_method(Capturers::Download, :content_type, "application/pdf") { ArchiveJob.perform_now(archive) }

    assert_equal %w[document], archive.captures.map(&:method_name)
    assert_equal "document", archive.reload.kind
  end

  test "does nothing when the archive already has captures" do
    archive = create_archive_with_captures({ "page" => "done" })

    stub_method(Capturers::Download, :content_type, nil) do
      assert_no_enqueued_jobs { ArchiveJob.perform_now(archive) }
    end
  end
end
