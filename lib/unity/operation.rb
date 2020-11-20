# frozen_string_literal: true

module Unity
  class Operation
    attr_reader :context, :args

    class Output
      def initialize(data)
        @data = data.transform_keys(&:to_s)
      end

      def method_missing(method_name, *args, &block)
        return super unless @data.key?(method_name.name)

        @data.fetch(method_name.name, nil)
      end

      def respond_to_missing(method_name, include_private = false)
        @data.key?(method_name.name) || super
      end

      def [](key)
        @data[key.to_s]
      end

      def []=(key, value)
        @data[key.to_s] = value
      end

      def as_json
        @data.as_json
      end

      def to_json(*args)
        @data.to_json(*args)
      end
    end

    def self.call(args)
      new.call(args)
    end

    # @param [Hash] context - A key/value set of options
    def initialize(context = nil)
      @context = context.is_a?(Hash) ? context : Unity::OperationContext.new
    end

    def call(args)
      raise "#call not implemented for #{self.class}"
    end

    class Error < StandardError
      attr_reader :code, :data

      def initialize(code, message, data = {})
        super(message)

        @code = code
        @data = data
      end

      def as_json
        { 'error' => message, 'data' => data }
      end
    end

    class OperationError < Error
      def initialize(message, data = {})
        super(400, message, data)
      end
    end
  end
end
