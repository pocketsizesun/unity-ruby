# frozen_string_literal: true

module Unity
  module Middlewares
    class AuthenticationMiddleware
      def initialize(app)
        @app = app
        @connection_pool = ConnectionPool.new(
          size: Unity.application.config.concurrency.to_i,
          timeout: Unity.application.config.auth_connection_timeout.to_i
        ) do
          Unity::Authentication::Client.new(config.auth_endpoint)
        end
        @auth_namespace = Unity.application.config.auth_namespace
      end

      def call(env)
        operation_context = env['unity.operation_context']
        policy_handler = Unity.application.find_policy(
          env['unity.operation_name']
        )
        unless policy_handler.nil?
          policy = policy_handler.new(operation_context)
          policy.call(env['unity.operation_input'])
        end

        if operation_context.fetch(:auth_enabled, true) == true
          auth_result = @connection_pool.with do |client|
            client.authenticate(
              request.get_header('HTTP_AUTHORIZATION'),
              "#{@auth_namespace}:#{operation_name}",
              resource: operation_context.fetch(:auth_resource, nil),
              conditions: operation_context.fetch(:auth_conditions, nil)
            )
          end

          operation_context.set(:auth_result, auth_result)
        end

        @app.call(env)
      rescue Unity::Authentication::Error => e
        [e.code, { 'content-type' => 'application/json' }, [e.as_json.to_json]]
      end
    end
  end
end
