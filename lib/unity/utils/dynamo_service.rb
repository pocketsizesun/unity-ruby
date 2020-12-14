module Unity
  module Utils
    class DynamoService
      include Singleton

      def checkout(&block)
        @connection_pool.with(&block)
      end

      def find_all(params)
        Enumerator.new do |arr|
          params = params.dup
          loop do
            result = @connection_pool.with do |conn|
              conn.query(params)
            end
            result.items.each { |item| arr << item }
            break if result.last_evaluated_key.nil?

            params[:exclusive_start_key] = result.last_evaluated_key
          end
        end
      end

      def query(params)
        @connection_pool.with do |conn|
          Unity.logger&.debug "[DynamoService] execute query: #{params.inspect}"
          conn.query(params)
        end
      end

      def method_missing(method_name, *args, &block)
        @connection_pool.with do |conn|
          conn.__send__(method_name, *args, &block)
        end
      end

      def respond_to_missing?(method_name, include_private = false)
        true
      end

      protected

      def initialize
        @connection_pool = ConnectionPool.new(
          pool_size: Unity.application.config.max_threads
        ) do
          Aws::DynamoDB::Client.new
        end
      end
    end
  end
end
