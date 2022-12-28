# frozen_string_literal: true

module Unity
  class Operation
    # @return [Unity::OperationContext]
    attr_reader :context

    OperationContext = Class.new(Hash)
    Output = ::Unity::OperationOutput
    EmptyOutput = ::Unity::OperationOutput.new(nil, 204).freeze

    # @param base [Class]
    # @return [void]
    def self.inherited(base)
      super
      operation_name = base.name.to_s.split('::').last
      Unity.application.operation(
        operation_name.slice(0, operation_name.length - 9), base
      )
    end


    class << self
      # @return [Class<Unity::OperationInput>]
      attr_reader :input_klass
    end

    # @param args [Hash<String, Object>]
    # @param context [Unity::OperationContext, nil]
    # @return [Unity::OperationOutput]
    def self.call(args, context = nil)
      new(context).call(args)
    end

    # @param klass [Class<Unity::OperationInput>]
    # @return [void]
    def self.with_input_klass(klass)
      @input_klass = klass
    end

    # Alias of `with_input_klass`
    # @param klass [Class<Unity::OperationInput>]
    # @return [void]
    def self.with_input(klass)
      @input_klass = klass
    end

    # @param [Unity::OperationContext, nil] context
    def initialize(context = nil)
      # @type [Unity::OperationContext]
      @context = \
        if context.is_a?(Unity::OperationContext)
          context
        else
          Unity::OperationContext.new
        end
    end

    # @sg-ignore
    # @param args [Hash<String, Object>]
    # @return [Unity::OperationOutput]
    def call(args)
      raise "#call not implemented for #{self.class}"
    end

    class OperationError < Error
      # @return [Integer]
      attr_reader :code

      # @return [Hash{String => Object}]
      attr_reader :data

      # @return [String]
      attr_reader :trace_id

      # @param message [String]
      # @param data [Hash{String => Object}]
      # @param code [Integer]
      def initialize(message, data = {}, code = 400)
        super(message)

        @data = data
        @code = code
      end

      # @return [Hash{String => Object}]
      def as_json
        { 'error' => message, 'data' => data }
      end

      # @return [Array<Integer, Hash, Array<String>>]
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
