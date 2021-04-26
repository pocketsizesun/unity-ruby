module Unity
  module Utils
    class RedisService
      include Singleton

      def checkout(&block)
        @connection_pool.with(&block)
      end

      def multi(&_block)
        checkout do |conn|
          conn.multi do
            yield(conn)
          end
        end
      end

      def method_missing(method_name, *args, **kwargs, &block)
        @connection_pool.with do |conn|
          conn.__send__(method_name, *args, **kwargs, &block)
        end
      end

      def respond_to_missing?(method_name, include_private = false)
        true
      end

      protected

      def initialize
        @connection_pool = ConnectionPool.new(
          pool_size: Unity.application.config.concurrency
        ) do
          Redis.new
        end
      end
    end
  end
end
