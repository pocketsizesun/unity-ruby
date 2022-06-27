# frozen_string_literal: true

module Unity
  module Middlewares
    class OperationExecutorMiddleware
      OPERATION_NOT_FOUND_RESPONSE = '{"error":"Operation not found","data":{}}'

      def initialize(app)
        @app = app
      end

      def call(env)
        operation_name = env['unity.operation_name']
        operation_handler = @app.find_operation(operation_name)
        return operation_not_found if operation_handler.nil?

        operation = operation_handler.new(env['unity.operation_context'])

        [
          200,
          { 'content-type' => 'application/json' },
          [operation.call(env['unity.operation_input']).to_json]
        ]
      rescue Unity::Operation::OperationError => e
        operation_error(env, e)
      rescue Exception => e # rubocop:disable Lint/RescueException
        uncaught_exception(env, e)
      end

      private

      def operation_not_found
        [
          404,
          { 'content-type' => 'application/json' },
          [OPERATION_NOT_FOUND_RESPONSE]
        ]
      end

      def internal_server_error(data)
        [
          500,
          { 'content-type' => 'application/json' },
          [
            {
              'error' => 'INTERNAL_SERVER_ERROR',
              'data' => data
            }.to_json
          ]
        ]
      end

      def operation_error(env, exception)
        Unity.logger&.warn(
          'message' => exception.message,
          'data' => exception.data,
          'operation_input' => env['unity.operation_input']
        )

        [
          400,
          { 'content-type' => 'application/json' },
          [Oj.dump(exception.as_json, mode: :compat)]
        ]
      end

      def uncaught_exception(env, exception)
        log_id = SecureRandom.uuid

        # log exception
        Unity.logger&.fatal(
          'log_id' => log_id,
          'message' => "service exception: #{exception.message} (#{exception.class})",
          'backtrace' => exception.backtrace,
          'operation_name' => env['unity.operation_name'],
          'operation_context' => env['unity.operation_context'].as_json,
          'operation_input' => env['unity.operation_input']
        )

        if @app.config.report_exception == true
          internal_server_error(
            'message' => "#{exception.message} (#{exception.class})",
            'data' => { 'backtrace' => exception.backtrace }
          )
        else
          internal_server_error('log_id' => log_id)
        end
      end
    end
  end
end
