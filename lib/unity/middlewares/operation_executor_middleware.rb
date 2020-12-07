# frozen_string_literal: true

module Unity
  module Middlewares
    class OperationExecutorMiddleware
      def call(env)
        request = env['rack.request']

        operation_name = env['unity.operation_name']
        operation_handler = Unity.application.find_operation(operation_name)
        return render_error('Operation not found') if operation_handler.nil?

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
          'operation_input' => operation_input
        )
        [400, { 'content-type' => 'application/json' }, [e.as_json.to_json]]
      rescue => e
        log = {
          'message' => 'Exception raised',
          'exception_message' => e.message,
          'exception_klass' => e.class.to_s,
          'exception_backtrace' => e.backtrace
        }
        Unity.logger&.fatal(log)
        [500, { 'content-type' => 'application/json' }, [log.to_json]]
      end

      private

      def parse_request_body(request)
        JSON.parse(request.body.read)
      end
    end
  end
end
