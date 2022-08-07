# frozen_string_literal: true

module Unity
  class Model
    class TagSetType < ActiveModel::Type::Value
      def type
        :tagset
      end

      def cast(value)
        case value
        when Hash
          value.each_with_object(Unity::TagSet.new) do |(key, value), tagset|
            tagset[key] = value
          end
        when Unity::TagSet then value
        else
          Unity::TagSet.new
        end
      end

      def changed?(old_value, new_value, _new_value_before_type_cast)
        old_value.to_sha256_binary != new_value.to_sha256_binary
      end
    end
  end
end
