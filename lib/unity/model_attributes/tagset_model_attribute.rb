# frozen_string_literal: true

module Unity
  module ModelAttributes
    class TagsetModelAttribute < ActiveModel::Type::Value
      private

      def cast_value(value)
        case value
        when Hash
          Unity::Utils::Tagset.new(value)
        else
          Hash.new
        end
      end
    end
  end
end

ActiveModel::Type.register(:tagset, Unity::ModelAttributes::TagsetModelAttribute)
