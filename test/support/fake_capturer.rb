# Capturers for the job tests. None of them touches the network or a tool.
module FakeCapturer
  # Writes one small text file and returns it as the original.
  class Writes < Capturers::Base
    def call
      log("fake: writing one file")
      ::File.write(path("hello.txt"), "hello from #{url}\n")
      [ output("original", "hello.txt", content_type: "text/plain") ]
    end
  end

  class Skips < Capturers::Base
    def call
      raise Capturers::Skip, "does not apply"
    end
  end

  class Fails < Capturers::Base
    def call
      raise Capturers::ToolFailed, "the tool said no"
    end
  end

  class Explodes < Capturers::Base
    def call
      raise ArgumentError, "a bug"
    end
  end

  class Private < Capturers::Base
    def call
      raise Capturers::NotPublic, "ask the owner"
    end
  end

  # Runs the block with Capturers::Router.capturer_for answering the given class for every method.
  def with_capturer(klass, &)
    stub_method(Capturers::Router, :capturer_for, ->(_method) { klass }, &)
  end
end
