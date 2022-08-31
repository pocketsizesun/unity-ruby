# frozen_string_literal: true

module Unity
  module Middlewares
    class RouterMiddleware
      HEALTH_CHECK_RESPONSE = '{"uptime": %d, "service": "%s"}'

      def initialize(app)
        @app = app
        @operation_executor = Unity::Middlewares::OperationExecutorMiddleware.new(app)
      end

      def call(env)
        request_path = env['rack.request'].path
        if request_path.empty? || request_path == '/'
          @operation_executor.call(env)
        elsif request_path == '/_status'
          health_check_response
        else
          @app.routes.each do |route|
            next unless route.match?(request_path)

            return route.call(env)
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
