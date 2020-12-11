# frozen_string_literal: true

module Unity
  module Utils
    class DynamoDateRangeWithTimeIdQuery
      QueryResult = Class.new do
        attr_accessor :count, :last_evaluated_key, :items

        def initialize(count = 0, last_evaluated_key = nil, items = [])
          @count = count
          @last_evaluated_key = last_evaluated_key
          @items = items
        end
      end

      def initialize(table_name, partition_key_name, sort_key_name, client = nil)
        @table_name = table_name
        @partition_key_name = partition_key_name.to_s
        @sort_key_name = sort_key_name.to_s
        @client = client || Unity::Utils::DynamoService.instance
      end

      def query(from, to, options = {})
        scan_index_forward = options.fetch(:scan_index_forward, true) == true
        exclusive_start_key = options.fetch(:exclusive_start_key, nil)
        partition_key_value = \
          if !exclusive_start_key.nil?
            exclusive_start_key[@partition_key_name]
          elsif scan_index_forward == true
            from.strftime('%Y-%m-%d')
          else
            to.strftime('%Y-%m-%d')
          end
        sort_key_value = \
          if !exclusive_start_key.nil?
            exclusive_start_key[@sort_key_name].to_i
          else
            Unity::TimeId.from(from)
          end

        date = Date.parse(partition_key_value)
        query_params = {
          table_name: @table_name,
          key_condition_expression: '#pk = :pk AND #sk BETWEEN :sk_0 AND :sk_1',
          expression_attribute_names: {
            '#pk' => @partition_key_name,
            '#sk' => @sort_key_name
          },
          expression_attribute_values: {
            ':pk' => partition_key_value,
            ':sk_0' => Unity::TimeId.min_for_time(from),
            ':sk_1' => Unity::TimeId.max_for_time(to)
          },
          scan_index_forward: scan_index_forward
        }.merge(build_query_options(options))

        if options.key?(:expression_attribute_names)
          query_params[:expression_attribute_names] = \
            query_params[:expression_attribute_names].merge(
              options.fetch(:expression_attribute_names)
            )
        end

        if options.key?(:expression_attribute_values)
          query_params[:expression_attribute_values] = \
            query_params[:expression_attribute_values].merge(
              options.fetch(:expression_attribute_values)
            )
        end

        query_result = QueryResult.new
        result = @client.query(query_params)
        query_result.count = result.count
        query_result.last_evaluated_key = \
          unless result.last_evaluated_key.nil?
            {
              @partition_key_name => \
                result.last_evaluated_key[@partition_key_name],
              @sort_key_name => result.last_evaluated_key[@sort_key_name].to_i
            }
          end
        query_result.items = result.items
        if result.last_evaluated_key.nil?
          if scan_index_forward == true
            next_date = date + 1
            unless next_date > to.to_date
              query_result.last_evaluated_key = {
                @partition_key_name => next_date.to_s,
                @sort_key_name => sort_key_value.to_i
              }
            end
          else
            prev_date = date - 1
            if prev_date >= from.to_date
              query_result.last_evaluated_key = {
                @partition_key_name => prev_date.to_s,
                @sort_key_name => sort_key_value.to_i
              }
            end
          end
        end

        query_result
      end

      private

      def build_query_options(options)
        {}.tap do |params|
          if options.key?(:exclusive_start_key)
            params[:exclusive_start_key] = {
              @partition_key_name => options[:exclusive_start_key][@partition_key_name],
              @sort_key_name => options[:exclusive_start_key][@sort_key_name].to_i
            }
          end
          if options.key?(:filter_expression)
            params[:filter_expression] = options.fetch(:filter_expression)
          end
          if options.key?(:projection_expression)
            params[:projection_expression] = options.fetch(
              :projection_expression
            )
          end
          params[:limit] = options.fetch(:limit).to_i if options.key?(:limit)
        end
      end
    end
  end
end
