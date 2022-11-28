# frozen_string_literal: true

module Unity
  class OperationInput
    # @!method self.attribute(name, type, options)
    #   Define an attribute
    #   @param name [Symbol]
    #   @param type [Symbol, Class, nil]
    #   @param options [Hash<Symbol, Object>]
    #   @return [void]

    include ActiveModel::Model
    include ActiveModel::Attributes
    include ActiveModel::AttributeMethods
    include ActiveModel::Validations
    include ActiveModel::Serialization
    include ActiveModel::Serializers::JSON

    ERROR_MESSAGE = '`%s` %s'

    def self.model_name
      attribute
      @model_name ||= ActiveModel::Name.new(self, nil, '_')
    end

    def self.model_name=(arg)
      @model_name = ActiveModel::Name.new(self, nil, arg.to_s)
    end

    # @param hash [Hash<String, Object>]
    # @return [self]
    def self.load(hash)
      # sanitize attributes
      attributes = hash.reject { |key, _| key[0] == '#' }
      attributes.compact!
      attributes.transform_keys!(&:to_sym)

      # create object
      obj = new(attributes)

      unless obj.valid?
        errors = obj.errors.collect do |error|
          if error.attribute == :_
            error.message
          else
            format(ERROR_MESSAGE, error.attribute, error.message)
          end
        end

        raise ::Unity::Operation::ValidationError.new(
          "Validation error: #{errors.join(', ')}",
          'errors' => obj.errors.details
        )
      end

      obj
    rescue ActiveModel::UnknownAttributeError => e
      if model_name.name == '_'
        raise ::Unity::Operation::OperationError, "Unknown parameter '#{e.attribute}'"
      else
        raise ::Unity::Operation::OperationError, "Unknown parameter '#{model_name.name}.#{e.attribute}'"
      end
    end

    def self.shape(name, &block)
      # create anonymous Shape class
      shape_klass = Class.new(Unity::OperationInput, &block)
      shape_klass.model_name = name

      # define active model attribute
      attribute(name, ShapeType.new(shape_klass))

      # add validator
      validate do
        public_send(name).valid?
      end
    end

    def require(attr_name)
      value = __send__(attr_name)
      return value unless value.nil?

      raise ::Unity::Operation::OperationError.new(
        "Missing required parameter '#{attr_name}'",
        'parameter_name' => attr_name
      )
    end

    class ShapeType < ActiveModel::Type::Value
      def initialize(shape_klass)
        super()

        @shape_klass = shape_klass
      end

      def cast(value)
        case value
        when @shape_klass then value
        when Hash then @shape_klass.load(value)
        end
      end

      def deserialize(value)
        raise "deserialize: #{value}"
      end
    end
  end
end
