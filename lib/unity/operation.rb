# frozen_string_literal: true

module Unity
  class Operation
    attr_reader :context, :args

    OperationContext = Class.new(Hash)
    Output = ::Unity::OperationOutput
    EmptyOutput = Class.new(::Unity::OperationOutput) do
      def initialize(code = 204)
        super(nil, code)
      end
    end

    def self.call(args, context = nil)
      new(context).call(args)
    end

    # @param [Unity::OperationContext] context
    def initialize(context = nil)
      @context = \
        if context.is_a?(Unity::OperationContext)
          context
        else
          Unity::OperationContext.new
        end
    end

    # @param args [Hash<String, Object>]
    # @return [Unity::OperationOutput]
    def call(args)
      raise "#call not implemented for #{self.class}"
    end

    class OperationError < Error
      attr_reader :code, :data, :trace_id

      def initialize(message, data = {}, code = 400)
        super(message)

        @data = data
        @code = code
      end

      def as_json
        { 'error' => message, 'data' => data }
      end

      def as_rack_response
        [code, { 'content-type' => 'application/json' }, [JSON.fast_generate(as_json)]]
      end
    end

    class ValidationError < OperationError
    end

    # HTTP Error Code: 401
    class AuthenticationError < OperationError
      def initialize(message, data = {})
        super(message, data, 401)
      end
    end

    # HTTP Error Code: 403
    class ForbiddenError < OperationError
      def initialize(message, data = {})
        super(message, data, 403)
      end
    end

    # HTTP Error Code: 404
    class ResourceNotFoundError < OperationError
      def initialize(message, data = {})
        super(message, data, 404)
      end
    end

    # HTTP Error Code: 409
    class ConflictError < OperationError
      def initialize(message, data = {})
        super(message, data, 409)
      end
    end

    # HTTP Error Code: 500
    class ServerError < OperationError
      def initialize(message, data = {})
        super(message, data, 500)
      end
    end
  end
end
