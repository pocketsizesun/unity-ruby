# frozen_string_literal: true

module Unity
  module Middlewares
    class OperationExecutorMiddleware
      OPERATION_NOT_FOUND_RESPONSE = '{"error":"Operation not found","data":{}}'

      def call(env)
        operation_name = env['unity.operation_name']
        operation_handler = Unity.application.find_operation(operation_name)
        return operation_not_found if operation_handler.nil?

        operation = operation_handler.new(env['unity.operation_context'])

        [
          200,
          { 'content-type' => 'application/json' },
          [operation.call(env['unity.operation_input']).to_json]
        ]
      rescue Unity::Operation::OperationError => e
        Unity.logger&.error(
          'message' => e.message,
          'data' => e.data,
          'operation_input' => env['unity.operation_input']
        )
        [400, { 'content-type' => 'application/json' }, [e.as_json.to_json]]
      rescue => e
        exception_id = Unity::TimeId.random

        Unity.logger&.fatal(
          'message' => "service exception: #{e.class}",
          'exception_id' => exception_id,
          'exception_message' => e.message,
          'exception_backtrace' => e.backtrace,
          'operation_input' => env['unity.operation_input']
        )
        if Unity.application.config.report_exception == true
          [
            500,
            { 'content-type' => 'application/json' },
            [
              {
                'error' => "service error: #{exception_id}",
                'data' => {}
              }.to_json
            ]
          ]
        else
          [
            500,
            { 'content-type' => 'application/json' },
            [
              {
                'error' => 'app.exception',
                'data' => {
                  'exception_message' => e.message,
                  'exception_klass' => e.class.to_s,
                  'exception_backtrace' => e.backtrace
                }
              }.to_json
            ]
          ]
        end
      end

      private

      def operation_not_found
        [
          404,
          { 'content-type' => 'application/json' },
          [OPERATION_NOT_FOUND_RESPONSE]
        ]
      end
    end
  end
end
