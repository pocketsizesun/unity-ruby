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

      def transaction(&_block)
        checkout do |conn|
          conn.multi { yield(conn) }
        end
      end

      def silent(&block)
        checkout(&block)
      rescue Redis::BaseError => e
        Unity.logger&.error(
          'message' => "redis error: #{e.message}",
          'exception_klass' => e.class.to_s,
          'exception_backtrace' => e.backtrace
        )
        nil
      end

      def redlock
        @redlock ||= Redlock::Client.new(
          [Redis.new],
          Unity.application.config.redlock || {}
        )
      end

      def get(key)
        @connection_pool.with do |redis|
          redis.get(key)
        end
      end

      def set(key, value, **kwargs)
        @connection_pool.with do |redis|
          redis.set(key, value, **kwargs)
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
