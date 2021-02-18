# frozen_string_literal: true

module Unity
  class Model
    include ActiveModel::Model
    include ActiveModel::Attributes
    include ActiveModel::AttributeMethods
    include ActiveModel::Validations
    include ActiveModel::Serialization
    include ActiveModel::Serializers::JSON

    ValidationError = Class.new(StandardError) do
      attr_reader :model

      def initialize(model)
        super("#{model.class} validation error")
        @model = model
      end

      def errors
        @model.errors
      end
    end

    def self.build!(*args)
      new(*args).tap(&:valid!)
    end

    def self.build(*args)
      new(*args)
    end

    def valid!
      return true if valid?

      raise ValidationError, self
    end
  end
end
