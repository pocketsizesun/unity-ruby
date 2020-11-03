module Unity
  module Utils
    class RedisService
      include Singleton

      def method_missing(method_name, *args, &block)
        @connection_pool.with do |conn|
          conn.__send__(method_name, *args, &block)
        end
      end

      protected

      def initialize
        @connection_pool = ConnectionPool.new(
          pool_size: Unity.application.config.max_threads
        ) do
          Redis.new
        end
      end
    end
  end
end
