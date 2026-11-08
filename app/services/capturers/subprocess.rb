require "open3"

module Capturers
  # Runs one external tool: a clean environment, arguments as a list (never a shell string), a
  # timeout, and a cap on the output that is kept for the log. On timeout the whole process group
  # gets TERM, then KILL.
  class Subprocess
    Result = Data.define(:status, :output) do
      def success?
        status&.success? == true
      end
    end

    # Environment variables that tools need. Nothing else from the worker's environment leaks in,
    # so a tool never sees a Stash secret.
    BASE_ENV = {
      "PATH" => ENV.fetch("PATH", "/usr/local/bin:/usr/bin:/bin"),
      "HOME" => ENV.fetch("CAPTURE_HOME", Dir.tmpdir),
      "LANG" => "C.UTF-8",
      "LC_ALL" => "C.UTF-8",
      "GIT_TERMINAL_PROMPT" => "0",
      "GIT_ASKPASS" => "/bin/false"
    }.freeze
    OUTPUT_CAP = 64.kilobytes

    def self.run(*command, chdir:, timeout: Capturers.timeout, env: {}, &on_line)
      new(command, chdir: chdir, timeout: timeout, env: env).run(&on_line)
    end

    def initialize(command, chdir:, timeout:, env:)
      @command = command.map(&:to_s)
      @chdir = chdir
      @timeout = timeout
      @env = BASE_ENV.merge(env)
    end

    def run
      output = +""
      status = nil
      Open3.popen2e(@env, *@command, chdir: @chdir, unsetenv_others: true, pgroup: true) do |stdin, out, waiter|
        stdin.close
        reader = Thread.new do
          out.each_line do |line|
            yield line if block_given?
            output << line if output.bytesize < OUTPUT_CAP
          end
        end
        unless waiter.join(@timeout.to_f)
          kill(waiter.pid)
          reader.join(5)
          raise Capturers::Timeout, "#{@command.first} ran for more than #{@timeout.to_i} seconds"
        end
        reader.join
        status = waiter.value
      end
      Result.new(status: status, output: output)
    rescue Errno::ENOENT
      raise Capturers::ToolFailed, "#{@command.first} is not installed"
    end

    private

    def kill(pid)
      Process.kill("TERM", -pid)
      sleep 2
      Process.kill("KILL", -pid)
    rescue Errno::ESRCH, Errno::EPERM
      nil
    end
  end
end
