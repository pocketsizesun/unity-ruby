# frozen_string_literal: true

module Unity
  class Model
    # @!parse
    #   # @param name [Symbol]
    #   # @param type [Object]
    #   # @param options [Object]
    #   # @return [void]
    #   def self.attribute(name, type, options)
    #   end

    include ActiveModel::Model
    include ActiveModel::Attributes
    include ActiveModel::AttributeMethods
    include ActiveModel::Dirty
    include ActiveModel::Validations
    include ActiveModel::Serialization
    include ActiveModel::Serializers::JSON

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

    class ValidationError < StandardError
      attr_reader :model

      ERROR_MESSAGE = '`%s` %s'

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
  end
end
