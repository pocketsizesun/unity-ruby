# frozen_string_literal: true

module Unity
  class Operation
    class Input
      include ActiveModel::Model
      include ActiveModel::Attributes
      include ActiveModel::AttributeMethods
      include ActiveModel::Validations
      include ActiveModel::Serialization
      include ActiveModel::Serializers::JSON

      ERROR_MESSAGE = '`%s` %s'

      def self.model_name
        @model_name ||= ActiveModel::Name.new(self, nil, 'input')
      end

      def self.load(hash)
        attributes = hash.reject { |key, _| key[0] == '#' }
        attributes.transform_keys!(&:to_sym)
        obj = new(attributes)

        unless obj.valid?
          errors = obj.errors.collect do |error|
            format(ERROR_MESSAGE, error.attribute, error.message)
          end

          raise ::Unity::Operation::ValidationError.new(
            "Validation error: #{errors.join(', ')}"
          )
        end

        obj
      rescue ActiveModel::UnknownAttributeError => e
        raise ::Unity::Operation::OperationError, "Unknown parameter '#{e.attribute}'"
      end

      def require(attr_name)
        value = __send__(attr_name)
        return value unless value.nil?

        raise ::Unity::Operation::OperationError.new(
          "Missing required parameter '#{attr_name}'",
          'parameter_name' => attr_name
        )
      end
    end
  end
end