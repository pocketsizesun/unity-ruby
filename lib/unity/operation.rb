# frozen_string_literal: true

module Unity
  class Operation
    attr_reader :context, :args

    OperationContext = Class.new(Hash)

    def self.input(klass = nil, &block)
      @input_klass = klass || Class.new(Unity::Operation::Input, &block)
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

    class Error < StandardError
      attr_reader :code, :data, :trace_id

      def initialize(message, data = {}, code = 400)
        super(message)

        @trace_id = SecureRandom.urlsafe_base64(18)
        @data = data
        @code = code
      end

      def as_json
        { 'error' => message, 'trace_id' => @trace_id, 'data' => data }
      end
    end

    class OperationError < Error
    end

    class ValidationError < Error
    end

    class ResourceNotFoundError < Error
      def initialize(message, data = {})
        super(message, data, 404)
      end
    end

    class ServerError < Error
      def initialize(message, data = {})
        super('Internal Server Error', data, 500)

        Unity.logger&.error(
          { 'message' => message, '@trace_id' => trace_id }.merge!(data)
        )
      end
    end
  end
end
