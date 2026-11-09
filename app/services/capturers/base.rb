module Capturers
  # What every capturer shares. A subclass implements #call and returns a list of Outputs.
  class Base
    attr_reader :capture, :workdir

    def initialize(capture, workdir)
      @capture = capture
      @workdir = workdir
    end

    def url
      capture.archive.url
    end

    def call
      raise NotImplementedError
    end

    private

    def log(line)
      capture.log!(line)
    end

    # Runs a tool in the work directory and logs its output. Raises ToolFailed on a non-zero exit.
    def run!(*command, env: {}, timeout: Capturers.timeout)
      log("$ #{command.map { |part| part.to_s.include?(" ") ? part.to_s.inspect : part }.join(" ")}")
      result = Subprocess.run(*command, chdir: workdir, timeout: timeout, env: env) { |line| log(line) }
      raise ToolFailed, "#{command.first} exited with status #{result.status.exitstatus}" unless result.success?

      result
    end

    # Runs the block, and when a tool fails, reads the last lines of the log for the reason:
    # a sign-in or a share that is missing (NotPublic) or a source that is gone (NotFound). Any
    # other failure stays a ToolFailed. `tool` names the tool in the message.
    def classify_tool_failure(tool, not_public:, not_found:)
      yield
    rescue ToolFailed => e
      tail = capture.log.to_s.last(4.kilobytes)
      if not_public.any? { |pattern| tail.match?(pattern) }
        raise NotPublic, "#{tool}: the source is private or needs a sign-in. " \
                         "Ask the owner to make it public, then run the archive again. (#{e.message})"
      elsif not_found.any? { |pattern| tail.match?(pattern) }
        raise NotFound, "#{tool}: the source is gone or the URL is wrong. (#{e.message})"
      end

      raise
    end

    def path(name)
      ::File.join(workdir, name)
    end

    # Raises TooLarge when a file passes the size limit.
    def check_size!(file)
      size = ::File.size(file)
      raise TooLarge, "#{::File.basename(file)} is #{size} bytes; the limit is #{Capturers.max_bytes}" if size > Capturers.max_bytes

      size
    end

    def output(role, name, content_type:, filename: name)
      check_size!(path(name))
      Output.new(role: role, path: path(name), filename: filename, content_type: content_type)
    end

    def write_json(name, value)
      ::File.write(path(name), JSON.pretty_generate(value))
    end
  end
end
