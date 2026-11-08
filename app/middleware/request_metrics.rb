# frozen_string_literal: true

class RequestMetrics
  def initialize(app)
    @app = app
  end

  def call(env)
    request = ActionDispatch::Request.new(env)
    start = Process.clock_gettime(Process::CLOCK_MONOTONIC)

    status, headers, response = @app.call(env)

    duration = Process.clock_gettime(Process::CLOCK_MONOTONIC) - start

    tags = [
      "method:#{request.request_method}",
      "status:#{status}",
      "controller:#{env['action_controller.instance']&.class&.name || 'unknown'}"
    ]

    StatsD.histogram('http.request.duration', (duration * 1000).round, tags: tags)
    StatsD.increment('http.request.count', tags: tags)

    [status, headers, response]
  rescue => e
    StatsD.increment('http.request.error', tags: ["error:#{e.class.name}"])
    raise
  end
end
