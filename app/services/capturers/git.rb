module Capturers
  # A git repository: a mirror clone, packed into one bundle file (original), plus the list of
  # refs (metadata). `git clone` runs with prompts off, so a private repository fails fast.
  class Git < Base
    def call
      clone_url = clone_url_for(url)
      log("git: cloning #{clone_url}")
      classify_tool_failure("git clone",
        not_public: [ /Authentication failed/i, /could not read Username/i, /Permission denied/i, /authentication required/i ],
        not_found: [ /Repository not found/i, /not found/i, /does not exist/i, /Could not resolve host/i ]) do
        run!("git", "clone", "--mirror", "--quiet", clone_url, "repo.git")
      end
      run!("git", "-C", "repo.git", "bundle", "create", "../repo.bundle", "--all")
      refs = run!("git", "-C", "repo.git", "for-each-ref", "--format=%(objectname) %(refname)").output
      head = run!("git", "-C", "repo.git", "symbolic-ref", "HEAD").output.strip
      ::File.write(path("refs.txt"), "HEAD -> #{head}\n#{refs}")
      FileUtils.rm_rf(path("repo.git"))

      [
        output("original", "repo.bundle", content_type: "application/x-git-bundle", filename: "#{repo_name}.bundle"),
        output("metadata", "refs.txt", content_type: "text/plain")
      ]
    end

    private

    # github.com/o/r/tree/main/x clones github.com/o/r. Other URLs clone as given.
    def clone_url_for(url)
      if (owner_repo = Router.github_repo(url))
        "https://github.com/#{owner_repo.join("/")}.git"
      else
        uri = URI.parse(url)
        segments = uri.path.split("/").reject(&:empty?)
        uri.path = "/" + segments.first(2).join("/")
        uri.query = nil
        uri.fragment = nil
        uri.to_s
      end
    end

    def repo_name
      ::File.basename(URI.parse(clone_url_for(url)).path, ".git").presence || "repo"
    end
  end
end
