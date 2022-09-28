# frozen_string_literal: true

module Unity
  module Middlewares
    class OperationExecutorMiddleware
      OPERATION_NOT_FOUND_RESPONSE = '{"error":"Operation not found","data":{}}'
      SEND_JSON_HEADERS = { 'content-type' => 'application/json' }.freeze
      RACK_INPUT_ENV = 'rack.input'
      OPERATION_NAME_ENV = 'unity.operation_name'
      OPERATION_CONTEXT_ENV = 'unity.operation_context'
      OPERATION_INPUT_ENV = 'unity.operation_input'

      def initialize(app)
        @app = app
      end

      def call(env)
        env[OPERATION_INPUT_ENV] = parse_request_body(env[RACK_INPUT_ENV]&.read)
        operation_name = env[OPERATION_NAME_ENV]
        operation_handler = @app.find_operation(operation_name)

        # if operation does not exists, return a 404 error
        if operation_handler.nil?
          return [404, SEND_JSON_HEADERS.dup, [OPERATION_NOT_FOUND_RESPONSE]]
        end

        # create operation instance
        operation = operation_handler.new(env[OPERATION_CONTEXT_ENV])

        # call operation with operation input
        result = operation.call(env[OPERATION_INPUT_ENV])

        result.as_rack_response
      rescue Unity::Operation::OperationError => e
        e.as_rack_response
      rescue Exception => e # rubocop:disable Lint/RescueException
        uncaught_exception(env, e)
      end

      private

      def parse_request_body(value)
        JSON.parse(value)
      rescue JSON::ParserError
        {}
      end

      def send_json(code, data)
        [code, SEND_JSON_HEADERS.dup, [JSON.fast_generate(data)]]
      end

      def uncaught_exception(env, exception)
        trace_id = SecureRandom.urlsafe_base64(18)

        # log exception
        Unity.logger&.fatal(
          '@trace_id' => trace_id,
          'message' => "service exception: #{exception.message} (#{exception.class})",
          'operation_name' => env[OPERATION_NAME_ENV],
          'operation_context' => env[OPERATION_CONTEXT_ENV].as_json,
          'operation_input' => env[OPERATION_INPUT_ENV],
          'backtrace' => exception.backtrace
        )

        if @app.config.report_exception == true
          data = {
            'message' => "#{exception.message} (#{exception.class})",
            'data' => { 'backtrace' => exception.backtrace }
          }

          [500, SEND_JSON_HEADERS.dup, [JSON.fast_generate(data)]]
        else
          [500, SEND_JSON_HEADERS.dup, [JSON.fast_generate({ 'trace_id' => trace_id, 'error' => 'Internal Server Error' })]]
        end
      end
    end
  end
end
