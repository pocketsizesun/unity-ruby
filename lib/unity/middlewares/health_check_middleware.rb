# frozen_string_literal: true

module Unity
  module Middlewares
    class HealthCheckMiddleware
      HEALTH_CHECK_RESPONSE = '{"uptime": %d, "service": "%s"}'

      def initialize
        @started_at = Time.now.to_i
      end

      def call(env)
        current_time = Process.clock_gettime(Process::CLOCK_REALTIME, :second).to_i
        [
          200,
          { 'content-type' => 'application/json' },
          [format(HEALTH_CHECK_RESPONSE, current_time - @started_at, Unity.application.name)]
        ]
      end
    end
  end
end
