module Unity
  module Utils
    class DynamoDateRangeQuery
      def initialize(client = nil)
        @client = client
      end

      def query(from, to, options = {})
        partition_key_value = \
          if options.key?(:starting_key)

          end
        query_params = {
          key_condition_expression: '#pk = :pk AND #sk BETWEEN :sk_0 AND :sk_1'
          expression_attribute_names: {
            '#pk' => options.fetch(:partition_key),
            '#sk' => options.fetch(:sort_key)
          },
          expression_attribute_values: {
            ':pk' => options.fetch(:starting_key, nil)
          }
        }
        result = @client.query(

        )
      end
    end
  end
end
