# frozen_string_literal: true

module Unity
  module Utils
    class DynamoFilterExpressionBuilder
      BuildResult = Struct.new(
        :expression_attribute_names,
        :expression_attribute_values,
        :filter_expression
      )

      def self.build(criteria)
        new(criteria).build
      end

      def initialize(criteria)
        @criteria = criteria
      end

      def build
        expression_attribute_names = {}
        expression_attribute_values = {}
        filter_expressions = []

        @criteria.each_with_index do |(filter_name, filter_value), filter_idx|
          case filter_value
          when Hash
            operator_name, operator_value = filter_value.to_a.first
            case operator_name
            when '$in'
              filter_clauses = []
              Array(operator_value).each_with_index do |item, idx|
                filter_value_key = ":filter_#{filter_idx}_v#{idx}"
                filter_clauses << filter_value_key
                expression_attribute_values[filter_value_key] = item.to_s
              end
              filter_expressions << "#filter_#{filter_idx} IN (#{filter_clauses.join(',')})"
            when '$gt'
              expression_attribute_values[":filter_#{filter_idx}_v0"] = operator_value
              filter_expressions << "#filter_#{filter_idx} > :filter_#{filter_idx}_v0"
            when '$gte'
              expression_attribute_values[":filter_#{filter_idx}_v0"] = operator_value
              filter_expressions << "#filter_#{filter_idx} >= :filter_#{filter_idx}_v0"
            when '$lt'
              expression_attribute_values[":filter_#{filter_idx}_v0"] = operator_value
              filter_expressions << "#filter_#{filter_idx} < :filter_#{filter_idx}_v0"
            when '$lte'
              expression_attribute_values[":filter_#{filter_idx}_v0"] = operator_value
              filter_expressions << "#filter_#{filter_idx} <= :filter_#{filter_idx}_v0"
            when '$neq'
              expression_attribute_values[":filter_#{filter_idx}_v0"] = operator_value
              filter_expressions << "#filter_#{filter_idx} <> :filter_#{filter_idx}_v0"
            when '$exists'
              if operator_value == false
                filter_expressions << "attribute_not_exists(#filter_#{filter_idx})"
              else
                filter_expressions << "attribute_exists(#filter_#{filter_idx})"
              end
            when '$type'
              expression_attribute_values[":filter_#{filter_idx}_v0"] = operator_value
              filter_expressions << "attribute_type(#filter_#{filter_idx}, :filter_#{filter_idx}_v0)"
            when '$begins_with'
              expression_attribute_values[":filter_#{filter_idx}_v0"] = operator_value
              filter_expressions << "begins_with(#filter_#{filter_idx}, :filter_#{filter_idx}_v0)"
            when '$not_begins_with'
              expression_attribute_values[":filter_#{filter_idx}_v0"] = operator_value
              filter_expressions << "NOT begins_with(#filter_#{filter_idx}, :filter_#{filter_idx}_v0)"
            when '$contains'
              expression_attribute_values[":filter_#{filter_idx}_v0"] = operator_value
              filter_expressions << "contains(#filter_#{filter_idx}, :filter_#{filter_idx}_v0)"
            when '$not_contains'
              expression_attribute_values[":filter_#{filter_idx}_v0"] = operator_value
              filter_expressions << "NOT contains(#filter_#{filter_idx}, :filter_#{filter_idx}_v0)"
            when '$size'
              expression_attribute_values[":filter_#{filter_idx}_v0"] = operator_value.to_i
              filter_expressions << "size(#filter_#{filter_idx}) = :filter_#{filter_idx}_v0)"
            when '$size_lt'
              expression_attribute_values[":filter_#{filter_idx}_v0"] = operator_value.to_i
              filter_expressions << "size(#filter_#{filter_idx}) < :filter_#{filter_idx}_v0)"
            when '$size_lte'
              expression_attribute_values[":filter_#{filter_idx}_v0"] = operator_value.to_i
              filter_expressions << "size(#filter_#{filter_idx}) <= :filter_#{filter_idx}_v0)"
            when '$size_gt'
              expression_attribute_values[":filter_#{filter_idx}_v0"] = operator_value.to_i
              filter_expressions << "size(#filter_#{filter_idx}) > :filter_#{filter_idx}_v0)"
            when '$size_gte'
              expression_attribute_values[":filter_#{filter_idx}_v0"] = operator_value.to_i
              filter_expressions << "size(#filter_#{filter_idx}) >= :filter_#{filter_idx}_v0)"
            else
              next
            end
          else
            expression_attribute_values[":filter_#{filter_idx}_v0"] = filter_value
            filter_expressions << "#filter_#{filter_idx} = :filter_#{filter_idx}_v0"
          end

          expression_attribute_names["#filter_#{filter_idx}"] = filter_name
        end

        BuildResult.new(
          expression_attribute_names,
          expression_attribute_values,
          filter_expressions.length > 0 ? filter_expressions.join(' AND ') : nil
        )
      end

      def as_params
        build.to_h
      end
    end
  end
end
