# frozen_string_literal: true

module Unity
  module Middlewares
    class OperationExecutorMiddleware
      OPERATION_NOT_FOUND_RESPONSE = '{"error":"Operation not found","data":{}}'
      EMPTY_BODY = [].freeze
      EMPTY_HEADERS = {}.freeze
      SEND_JSON_HEADERS = { 'content-type' => 'application/json' }.freeze

      def initialize(app)
        @app = app
      end

      def call(env)
        operation_name = env['unity.operation_name']
        operation_handler = @app.find_operation(operation_name)
        return operation_not_found if operation_handler.nil?

        operation = operation_handler.new(env['unity.operation_context'])
        result = operation.call(env['unity.operation_input'])

        if !result.empty?
          [200, SEND_JSON_HEADERS, [result.to_json]]
        else
          [204, EMPTY_HEADERS, EMPTY_BODY]
        end
      rescue Unity::Operation::OperationError => e
        operation_error(env, e)
      rescue Exception => e # rubocop:disable Lint/RescueException
        uncaught_exception(env, e)
      end

      private

      def send_json(code, body)
        [code, SEND_JSON_HEADERS, [body]]
      end

      def operation_not_found
        send_json(404, OPERATION_NOT_FOUND_RESPONSE)
      end

      def internal_server_error(data)
        send_json(
          500,
          JSON.dump(
            {
              'error' => 'INTERNAL_SERVER_ERROR',
              'data' => data
            }
          )
        )
      end

      def operation_error(env, exception)
        if env['rack.request']['X-Unity-Debug'] == '1'
          Unity.logger&.info(
            'message' => exception.message,
            '@trace_id' => exception.trace_id,
            'data' => exception.data,
            'operation_name' => env['unity.operation_name'],
            'operation_input' => env['unity.operation_input']
          )
        end

        send_json(exception.code, Oj.dump(exception.as_json, mode: :compat))
      end

      def uncaught_exception(env, exception)
        trace_id = SecureRandom.urlsafe_base64(18)

        # log exception
        Unity.logger&.fatal(
          '@trace_id' => trace_id,
          'message' => "service exception: #{exception.message} (#{exception.class})",
          'operation_name' => env['unity.operation_name'],
          'operation_context' => env['unity.operation_context'].as_json,
          'operation_input' => env['unity.operation_input'],
          'backtrace' => exception.backtrace
        )

        if @app.config.report_exception == true
          internal_server_error(
            'message' => "#{exception.message} (#{exception.class})",
            'data' => { 'backtrace' => exception.backtrace }
          )
        else
          internal_server_error('trace_id' => trace_id)
        end
      end
    end
  end
end
