# frozen_string_literal: true

module Unity
  module Application
    class OperationHandler
      def initialize(container)
        @container = container
      end

      def call(env)
        operation = env['operation.handler'].new(env['operation.context'])
        # @container.logger&.debug "process operation: #{operation.class.to_s}"
        [
          200,
          { 'content-type' => 'application/json' },
          [JSON.dump(operation.call(env['operation.input']))]
        ]
      end
    end
  end
end
