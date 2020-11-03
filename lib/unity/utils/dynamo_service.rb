module Unity
  module Utils
    class DynamoService
      include Singleton

      def scan(params)
        @connection_pool.with { |conn| conn.scan(params) }
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
