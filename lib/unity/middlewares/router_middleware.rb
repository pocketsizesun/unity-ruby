# frozen_string_literal: true

module Unity
  module Middlewares
    class RouterMiddleware
      HEALTH_CHECK_RESPONSE = '{"uptime": %d, "service": "%s"}'
      HEALTH_CHECK_PATH = '/_status'
      OPERATION_EXECUTION_PATH = '/'
      RACK_REQUEST_ENV = 'rack.request'
      OPERATION_NAME_ENV = 'unity.operation_name'
      OPERATION_CONTEXT_ENV = 'unity.operation_context'

      def initialize(app)
        @app = app
        @operation_executor = Unity::Middlewares::OperationExecutorMiddleware.new(app)
      end

      def call(env)
        request = Rack::Request.new(env)
        request_path = request.path

        if request_path.empty? || request_path == OPERATION_EXECUTION_PATH
          env[OPERATION_NAME_ENV] = request.params['Operation']
          env[OPERATION_CONTEXT_ENV] ||= Unity::OperationContext.new

          @operation_executor.call(env)
        elsif request_path == HEALTH_CHECK_PATH
          health_check_response
        else
          @app.routes.each do |route|
            next unless route.match?(request_path)

            return route.call(request)
          end

          [404, {}, []]
        end
      end

      private

      def health_check_response
        [
          200,
          { 'content-type' => 'application/json' },
          [format(HEALTH_CHECK_RESPONSE, @app.uptime, @app.app_name)]
        ]
      end
    end
  end
end
