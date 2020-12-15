# frozen_string_literal: true

module Unity
  module Utils
    class DynamoFilterExpressionBuilder
      BuildResult = Struct.new(
        :expression_attribute_names,
        :expression_attribute_values,
        :filter_expression
      )

      def self.build(criteria, **kwargs)
        new(criteria, **kwargs).build
      end

      def self.build_and_update!(params, criteria, **kwargs)
        builder_result = new(criteria, **kwargs).build
        return params if builder_result.filter_expression.nil?

        params.tap do
          params[:expression_attribute_names] = \
            params.fetch(:expression_attribute_names, {}).merge(
              builder_result.expression_attribute_names
            )
          params[:expression_attribute_values] = \
            params.fetch(:expression_attribute_values, {}).merge(
              builder_result.expression_attribute_values
            )
          params[:filter_expression] = \
            if !params[:filter_expression].nil?
              <<~EXPR
                #{params[:filter_expression]} AND #{builder_result.filter_expression}
              EXPR
            else
              builder_result.filter_expression
            end
        end
      end

      def initialize(criteria, **kwargs)
        @criteria = criteria
        @parent_attributes = kwargs.fetch(:path, '').to_s.split('.')
      end

      def expression_attribute_name_path
        @expression_attribute_name_path ||= @parent_attributes.map do |item|
          "##{item}"
        end.join('.')
      end

      def build
        expression_attribute_names = {}.tap do |attribute_names|
          @parent_attributes.each do |parent_attribute|
            attribute_names["##{parent_attribute}"] = parent_attribute
          end
        end
        expression_attribute_values = {}
        filter_expressions = []

        @criteria.each_with_index do |(filter_name, filter_value), filter_idx|
          filter_attribute_name = build_filter_attribute_name(filter_name)
          case filter_value
          when Hash
            sub_filter_expressions = []
            filter_value.each_with_index do |(operator_name, operator_value), filter_operator_idx|
              case operator_name
              when '$in'
                filter_clauses = []
                Array(operator_value).each_with_index do |item, idx|
                  filter_value_key = ":filter_#{filter_idx}_#{filter_operator_idx}_v#{idx}"
                  filter_clauses << filter_value_key
                  expression_attribute_values[filter_value_key] = item.to_s
                end
                sub_filter_expressions << "#{filter_attribute_name} IN (#{filter_clauses.join(',')})"
              when '$not_in'
                filter_clauses = []
                Array(operator_value).each_with_index do |item, idx|
                  filter_value_key = ":filter_#{filter_idx}_#{filter_operator_idx}_v#{idx}"
                  filter_clauses << filter_value_key
                  expression_attribute_values[filter_value_key] = item.to_s
                end
                sub_filter_expressions << "NOT #{filter_attribute_name} IN (#{filter_clauses.join(',')})"
              when '$gt'
                expression_attribute_values[":filter_#{filter_idx}_#{filter_operator_idx}_v0"] = operator_value
                sub_filter_expressions << "#{filter_attribute_name} > :filter_#{filter_idx}_#{filter_operator_idx}_v0"
              when '$gte'
                expression_attribute_values[":filter_#{filter_idx}_#{filter_operator_idx}_v0"] = operator_value
                sub_filter_expressions << "#{filter_attribute_name} >= :filter_#{filter_idx}_#{filter_operator_idx}_v0"
              when '$lt'
                expression_attribute_values[":filter_#{filter_idx}_#{filter_operator_idx}_v0"] = operator_value
                sub_filter_expressions << "#{filter_attribute_name} < :filter_#{filter_idx}_#{filter_operator_idx}_v0"
              when '$lte'
                expression_attribute_values[":filter_#{filter_idx}_#{filter_operator_idx}_v0"] = operator_value
                sub_filter_expressions << "#{filter_attribute_name} <= :filter_#{filter_idx}_#{filter_operator_idx}_v0"
              when '$neq'
                expression_attribute_values[":filter_#{filter_idx}_#{filter_operator_idx}_v0"] = operator_value
                sub_filter_expressions << "#{filter_attribute_name} <> :filter_#{filter_idx}_#{filter_operator_idx}_v0"
              when '$exists'
                if operator_value == false
                  sub_filter_expressions << "attribute_not_exists(#{filter_attribute_name})"
                else
                  sub_filter_expressions << "attribute_exists(#{filter_attribute_name})"
                end
              when '$type'
                expression_attribute_values[":filter_#{filter_idx}_#{filter_operator_idx}_v0"] = operator_value
                sub_filter_expressions << "attribute_type(#{filter_attribute_name}, :filter_#{filter_idx}_#{filter_operator_idx}_v0)"
              when '$begins_with'
                expression_attribute_values[":filter_#{filter_idx}_#{filter_operator_idx}_v0"] = operator_value
                sub_filter_expressions << "begins_with(#{filter_attribute_name}, :filter_#{filter_idx}_#{filter_operator_idx}_v0)"
              when '$not_begins_with'
                expression_attribute_values[":filter_#{filter_idx}_#{filter_operator_idx}_v0"] = operator_value
                sub_filter_expressions << "NOT begins_with(#{filter_attribute_name}, :filter_#{filter_idx}_#{filter_operator_idx}_v0)"
              when '$contains'
                if operator_value.is_a?(Array)
                  contains_exprs = []
                  operator_value.each_with_index do |item, item_idx|
                    expression_attribute_values[":filter_#{filter_idx}_#{filter_operator_idx}_v#{item_idx}"] = item
                    contains_exprs << "contains(#{filter_attribute_name}, :filter_#{filter_idx}_#{filter_operator_idx}_v#{item_idx})"
                  end
                  sub_filter_expressions << contains_exprs.join(' OR ')
                else
                  expression_attribute_values[":filter_#{filter_idx}_#{filter_operator_idx}_v0"] = operator_value
                  sub_filter_expressions << "contains(#{filter_attribute_name}, :filter_#{filter_idx}_#{filter_operator_idx}_v0)"
                end
              when '$contains_all'
                if operator_value.is_a?(Array)
                  contains_exprs = []
                  operator_value.each_with_index do |item, item_idx|
                    expression_attribute_values[":filter_#{filter_idx}_#{filter_operator_idx}_v#{item_idx}"] = item
                    contains_exprs << "contains(#{filter_attribute_name}, :filter_#{filter_idx}_#{filter_operator_idx}_v#{item_idx})"
                  end
                  sub_filter_expressions << contains_exprs.join(' AND ')
                else
                  expression_attribute_values[":filter_#{filter_idx}_#{filter_operator_idx}_v0"] = operator_value
                  sub_filter_expressions << "contains(#{filter_attribute_name}, :filter_#{filter_idx}_#{filter_operator_idx}_v0)"
                end
              when '$not_contains'
                if operator_value.is_a?(Array)
                  contains_exprs = []
                  operator_value.each_with_index do |item, item_idx|
                    expression_attribute_values[":filter_#{filter_idx}_#{filter_operator_idx}_v#{item_idx}"] = item
                    contains_exprs << "NOT contains(#{filter_attribute_name}, :filter_#{filter_idx}_#{filter_operator_idx}_v#{item_idx})"
                  end
                  sub_filter_expressions << contains_exprs.join(' OR ')
                else
                  expression_attribute_values[":filter_#{filter_idx}_#{filter_operator_idx}_v0"] = operator_value
                  sub_filter_expressions << "NOT contains(#{filter_attribute_name}, :filter_#{filter_idx}_#{filter_operator_idx}_v0)"
                end
              when '$not_contains_all'
                if operator_value.is_a?(Array)
                  contains_exprs = []
                  operator_value.each_with_index do |item, item_idx|
                    expression_attribute_values[":filter_#{filter_idx}_#{filter_operator_idx}_v#{item_idx}"] = item
                    contains_exprs << "NOT contains(#{filter_attribute_name}, :filter_#{filter_idx}_#{filter_operator_idx}_v#{item_idx})"
                  end
                  sub_filter_expressions << contains_exprs.join(' AND ')
                else
                  expression_attribute_values[":filter_#{filter_idx}_#{filter_operator_idx}_v0"] = operator_value
                  sub_filter_expressions << "NOT contains(#{filter_attribute_name}, :filter_#{filter_idx}_#{filter_operator_idx}_v0)"
                end
              when '$size'
                expression_attribute_values[":filter_#{filter_idx}_#{filter_operator_idx}_v0"] = operator_value.to_i
                sub_filter_expressions << "size(#{filter_attribute_name}) = :filter_#{filter_idx}_#{filter_operator_idx}_v0)"
              when '$size_lt'
                expression_attribute_values[":filter_#{filter_idx}_#{filter_operator_idx}_v0"] = operator_value.to_i
                sub_filter_expressions << "size(#{filter_attribute_name}) < :filter_#{filter_idx}_#{filter_operator_idx}_v0)"
              when '$size_lte'
                expression_attribute_values[":filter_#{filter_idx}_#{filter_operator_idx}_v0"] = operator_value.to_i
                sub_filter_expressions << "size(#{filter_attribute_name}) <= :filter_#{filter_idx}_#{filter_operator_idx}_v0)"
              when '$size_gt'
                expression_attribute_values[":filter_#{filter_idx}_#{filter_operator_idx}_v0"] = operator_value.to_i
                sub_filter_expressions << "size(#{filter_attribute_name}) > :filter_#{filter_idx}_#{filter_operator_idx}_v0)"
              when '$size_gte'
                expression_attribute_values[":filter_#{filter_idx}_#{filter_operator_idx}_v0"] = operator_value.to_i
                sub_filter_expressions << "size(#{filter_attribute_name}) >= :filter_#{filter_idx}_#{filter_operator_idx}_v0)"
              else
                next
              end
            end

            filter_expressions << "(#{sub_filter_expressions.join(' AND ')})"
          else
            expression_attribute_values[":filter_#{filter_idx}_0_v0"] = filter_value
            filter_expressions << "#{filter_attribute_name} = :filter_#{filter_idx}_0_v0"
          end

          filter_name.split('.').each do |item|
            expression_attribute_names["##{item}"] = item
          end
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

      private

      def build_filter_attribute_name(filter_name)
        arr = []
        if @parent_attributes.length > 0
          arr.concat(@parent_attributes)
        end
        arr.concat(filter_name.split('.')).map do |item|
          "##{item}"
        end.join('.')
      end
    end
  end
end
