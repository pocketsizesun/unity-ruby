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

    def self.attribute_builder
      @attribute_builder ||= ActiveModel::AttributeSet::Builder.new(
        attribute_types
      )
    end

    def self.init_with_attributes(attributes)
      allocate.initialize_with(attributes, false)
    end

    def initialize_with(attributes, new_record = false)
      @attributes = self.class.attribute_builder.build_from_database(attributes)
      @new_record = new_record
      self
    end

    def self.build!(*args)
      new(*args).tap(&:valid!)
    end

    def self.build(*args)
      new(*args)
    end

    def assign_attributes_from_database(hash)
      hash.each do |attr_name, attr_value|
        @attributes.write_from_database(attr_name.name, attr_value)
      end
    end
  end
end
