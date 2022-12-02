# frozen_string_literal: true

module Unity
  class Model
    include ActiveModel::Model
    include ActiveModel::Attributes
    include ActiveModel::AttributeMethods
    include ActiveModel::Dirty
    include ActiveModel::Validations
    include ActiveModel::Serialization
    include ActiveModel::Serializers::JSON

    # @!method self.attribute(name, type = nil, options = nil)
    #   @param name [Symbol]
    #   @param type [Symbol, Object, nil]
    #   @param options [Hash{Symbol => Object}, nil]
    #   @return [void]

    # @return [ActiveModel::AttributeSet::Builder]
    def self.attribute_builder
      @attribute_builder ||= ActiveModel::AttributeSet::Builder.new(
        attribute_types
      )
    end

    # @param attributes [Hash<String, Object>]
    # @return [self]
    def self.init_with_attributes(attributes)
      allocate.initialize_with(attributes, false)
    end

    # @param attributes [Hash<String, Object>]
    # @return [self]
    def initialize_with(attributes, new_record = false)
      @attributes = self.class.attribute_builder.build_from_database(attributes)
      @new_record = new_record
      self
    end

    # @return [self]
    def self.build!(*args)
      new(*args).tap(&:valid!)
    end

    # @return [self]
    def self.build(*args)
      new(*args)
    end

    def assign_attributes_from_database(hash)
      hash.each do |attr_name, attr_value|
        @attributes.write_from_database(attr_name.name, attr_value)
      end
    end

    def valid!
      return true if valid?

      raise ValidationError, self
    end

    class Error < StandardError
    end

    class ValidationError < Error
      # @param model [Unity::Model]
      attr_reader :model

      ERROR_MESSAGE = '`%s` %s'

      # @param model [Unity::Model]
      def initialize(model)
        @model = model

        super(
          model.errors.collect do |error|
            if error.attribute == :_
              error.message
            else
              format(ERROR_MESSAGE, error.attribute, error.message)
            end
          end.join(', ')
        )
      end
    end

    class RecordNotUniqueError < Error
      # @param model [Unity::Model]
      attr_reader :model

      # @param model [Unity::Model]
      def initialize(model)
        super("#{model.model_name&.name} already exists")
        @model = model
      end
    end
  end
end
