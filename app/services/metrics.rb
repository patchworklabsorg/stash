# frozen_string_literal: true

# Centralized metrics helper
#
# Usage:
#   Metrics.increment('user.signup')
#   Metrics.gauge('queue.size', queue.size)
#   Metrics.measure('api.request') { api_call }
#   Metrics.histogram('response.size', response.body.size)
#
module Metrics
  class << self
    # Count occurrences
    def increment(name, value = 1, tags: [])
      StatsD.increment(name, value, tags: tags)
    end

    # Track current value
    def gauge(name, value, tags: [])
      StatsD.gauge(name, value, tags: tags)
    end

    # Measure timing of a block
    def measure(name, tags: [], &block)
      StatsD.measure(name, tags: tags, &block)
    end

    # Track distribution of values
    def histogram(name, value, tags: [])
      StatsD.histogram(name, value, tags: tags)
    end

    # Track unique values
    def set(name, value, tags: [])
      StatsD.set(name, value, tags: tags)
    end

    # Time a block and record
    def time(name, tags: [])
      start = Process.clock_gettime(Process::CLOCK_MONOTONIC)
      result = yield
      duration = Process.clock_gettime(Process::CLOCK_MONOTONIC) - start
      histogram("#{name}.duration", (duration * 1000).round, tags: tags)
      result
    end
  end
end
