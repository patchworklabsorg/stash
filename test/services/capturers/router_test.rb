require "test_helper"

class Capturers::RouterTest < ActiveSupport::TestCase
  Router = Capturers::Router

  test "a GitHub repository gets github, git and page" do
    assert_equal %w[github git page], Router.methods_for("https://github.com/patchworklabsorg/stash")
    assert_equal %w[github git page], Router.methods_for("https://github.com/patchworklabsorg/stash/tree/main/app")
    assert_equal [ "patchworklabsorg", "stash" ], Router.github_repo("https://github.com/patchworklabsorg/stash.git")
  end

  test "a GitHub owner or a reserved path is a page" do
    assert_equal %w[page], Router.methods_for("https://github.com/patchworklabsorg")
    assert_equal %w[page], Router.methods_for("https://github.com/settings/profile")
    assert_equal %w[page], Router.methods_for("https://github.com/orgs/patchworklabsorg/repositories")
  end

  test "other git hosts and .git URLs get git and page" do
    assert_equal %w[git page], Router.methods_for("https://gitlab.com/group/project")
    assert_equal %w[git page], Router.methods_for("https://codeberg.org/user/repo")
    assert_equal %w[git page], Router.methods_for("https://git.example.org/x/y.git")
    assert_equal %w[page], Router.methods_for("https://gitlab.com/explore")
  end

  test "Google Docs, Slides, Sheets and Drawings get document and page" do
    assert_equal %w[document page], Router.methods_for("https://docs.google.com/presentation/d/1AbC-dEf/edit#slide=id.p")
    assert_equal %w[document page], Router.methods_for("https://docs.google.com/document/d/1AbC/edit")
    assert_equal [ "spreadsheets", "1AbC" ], Router.google_document("https://docs.google.com/spreadsheets/d/1AbC/edit")
    assert_equal %w[page], Router.methods_for("https://docs.google.com/forms/d/1AbC/viewform")
  end

  test "a file by extension gets document only" do
    assert_equal %w[document], Router.methods_for("https://example.org/deck.pptx")
    assert_equal %w[document], Router.methods_for("https://example.org/paper.PDF?download=1")
    assert_equal "document", Router.kind_for("https://example.org/notes.docx")
  end

  test "video hosts get video and page" do
    assert_equal %w[video page], Router.methods_for("https://www.youtube.com/watch?v=abc")
    assert_equal %w[video page], Router.methods_for("https://youtu.be/abc")
    assert_equal %w[video page], Router.methods_for("https://www.loom.com/share/abc")
  end

  test "post URLs on gallery hosts get gallery and page, profiles get page" do
    assert_equal %w[gallery page], Router.methods_for("https://www.instagram.com/p/Cabc123/")
    assert_equal %w[gallery page], Router.methods_for("https://x.com/someone/status/1234567890")
    assert_equal %w[gallery page], Router.methods_for("https://www.reddit.com/r/pics/comments/abc123/title/")
    assert_equal %w[page], Router.methods_for("https://www.instagram.com/someone/")
    assert_equal %w[page], Router.methods_for("https://x.com/someone")
  end

  test "a content type decides for a plain URL" do
    assert_equal %w[document], Router.methods_for("https://example.org/download?id=1", content_type: "application/pdf")
    assert_equal %w[file], Router.methods_for("https://example.org/download?id=1", content_type: "application/zip; charset=binary")
    assert_equal %w[page], Router.methods_for("https://example.org/download?id=1", content_type: "text/html; charset=utf-8")
    assert_equal %w[page], Router.methods_for("https://example.org/readme", content_type: "text/plain")
    assert_equal %w[page], Router.methods_for("https://example.org/", content_type: nil)
  end

  test "every method has a capturer" do
    Router::METHODS.each { |method| assert_kind_of Class, Router.capturer_for(method) }
  end

  test "garbage is a page" do
    assert_equal "page", Router.kind_for("::not a url::")
    assert_equal %w[page], Router.methods_for("")
  end
end
