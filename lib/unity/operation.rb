# frozen_string_literal: true

module Unity
  class Operation
    attr_reader :context, :args

    OperationContext = Class.new(Hash)
    Output = ::Unity::OperationOutput

    def self.input(klass = nil, &block)
      @input_klass = klass || Class.new(Unity::OperationInput, &block)
    end

    def self.input_klass
      @input_klass
    end

    def self.call(args, context = nil)
      new(context).call(args)
    end

    # @param [Hash] context - A key/value set of options
    def initialize(context = nil)
      @context = \
        if context.is_a?(Unity::OperationContext)
          context
        else
          Unity::OperationContext.new
        end
    end

    def call(args)
      raise "#call not implemented for #{self.class}"
    end

    def input
      self.class.input_klass
    end

    class OperationError < Error
      attr_reader :code, :data, :trace_id

      def initialize(message, data = {}, code = 400)
        super(message)

        @trace_id = SecureRandom.urlsafe_base64(18)
        @data = data
        @code = code
      end

      def as_json
        { 'trace_id' => @trace_id, 'error' => message, 'data' => data }
      end
    end

    class ValidationError < OperationError
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
