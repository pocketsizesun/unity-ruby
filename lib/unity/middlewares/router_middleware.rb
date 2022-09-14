# frozen_string_literal: true

module Unity
  module Middlewares
    class RouterMiddleware
      HEALTH_CHECK_RESPONSE = '{"uptime": %d, "service": "%s"}'
      HEATH_CHECK_PATH = '/_status'
      OPERATION_EXECUTION_PATH = '/'
      RACK_REQUEST_ENV = 'rack.request'

      def initialize(app)
        @app = app
        @operation_executor = Unity::Middlewares::OperationExecutorMiddleware.new(app)
      end

      def call(env)
        request_path = env[RACK_REQUEST_ENV].path
        if request_path.empty? || request_path == OPERATION_EXECUTION_PATH
          @operation_executor.call(env)
        elsif request_path == HEALTH_CHECK_PATH
          health_check_response
        else
          @app.routes.each do |route|
            next unless route.match?(request_path)

            return route.call(env[RACK_REQUEST_ENV])
          end

          [404, {}, []]
        end
      end

      private

      def health_check_response
        [
          200,
          { 'content-type' => 'application/json' },
          [format(HEALTH_CHECK_RESPONSE, @app.uptime, @app.name)]
        ]
      end
    end
  end
end
