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
