# frozen_string_literal: true

module Unity
  module Middlewares
    class HealthCheckMiddleware
      HEALTH_CHECK_RESPONSE = '{"uptime": %d, "service": "%s"}'

      def initialize(app)
        @started_at = Time.now.to_i
        @app = app
      end

      def call(_env)
        [
          200,
          { 'content-type' => 'application/json' },
          [format(HEALTH_CHECK_RESPONSE, @app.uptime, @app.name)]
        ]
      end
    end
  end
end
