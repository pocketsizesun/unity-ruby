# frozen_string_literal: true

module Unity
  module ModelAttributes
    class TagsetModelAttribute < ActiveModel::Type::Value
      private

      def cast_value(value)
        case value
        when Hash
          value.transform_keys(&:to_s).transform_values(&:to_s)
        else {}
        end
      end
    end
  end
end

ActiveModel::Type.register(:tagset, Unity::ModelAttributes::TagsetModelAttribute)
