# frozen_string_literal: true

module Unity
  module Middlewares
    class OperationExecutorMiddleware
      OPERATION_NOT_FOUND_RESPONSE = '{"error":"Operation not found","data":{}}'
      SEND_JSON_HEADERS = { 'content-type' => 'application/json' }.freeze

      def initialize(app)
        @app = app
      end

      def call(env)
        operation_name = env['unity.operation_name']
        operation_handler = @app.find_operation(operation_name)

        # if operation does not exists, return a 404 error
        if operation_handler.nil?
          return [404, SEND_JSON_HEADERS.dup, [OPERATION_NOT_FOUND_RESPONSE]]
        end

        # create operation instance
        operation = operation_handler.new(env['unity.operation_context'])

        # call operation with operation input
        result = operation.call(env['unity.operation_input'])

        result.as_rack_response
      rescue Unity::Operation::OperationError => e
        [exception.code, SEND_JSON_HEADERS.dup, [JSON.dump(exception.as_json)]]
      rescue Exception => e # rubocop:disable Lint/RescueException
        uncaught_exception(env, e)
      end

      private

      def send_json(code, body)
        [code, SEND_JSON_HEADERS.dup, [JSON.dump(body)]]
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
          data = {
            'message' => "#{exception.message} (#{exception.class})",
            'data' => { 'backtrace' => exception.backtrace }
          }

          [500, SEND_JSON_HEADERS.dup, [JSON.dump(data)]]
        else
          [500, SEND_JSON_HEADERS.dup, [JSON.dump({ 'trace_id' => trace_id, 'error' => 'Internal Server Error' })]]
        end
      end
    end
  end
end
