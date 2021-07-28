# frozen_string_literal: true

module Unity
  class Coordination
    DEFAULT_TTL = 86_400
    DEFAULT_LOCK_TTL = 60
    DEFAULT_DATA_TTL = 3600

    Error = Class.new(StandardError)

    LockError = Class.new(Error) do
      attr_reader :lock_name

      def initialize(lock_name)
        @lock_name = lock_name
        super("unable to get lock for: #{lock_name}")
      end
    end

    WriteError = Class.new(Error) do
      attr_reader :lock_name

      def initialize(lock_name)
        @lock_name = lock_name
        super("write lock for '#{lock_name}' is not valid")
      end
    end

    def initialize(namespace: nil, redlock: nil)
      @redlock = redlock || Unity::Utils::RedisService.instance.redlock
      @namespace = namespace || Unity.application.config.redlock[:namespace] || Unity.application.name
    end

    def with_lock!(name, ttl: DEFAULT_LOCK_TTL)
      lock_key_name = lock_key_for(name)

      @redlock.lock(lock_key_name, ttl * 1000) do |lock_info|
        raise LockError, lock_key_name unless lock_info

        return yield(LockData.new(@redlock, lock_info, lock_key_name))
      end
    end

    private

    def current_time
      Process.clock_gettime(Process::CLOCK_REALTIME, :second)
    end

    def lock_key_for(str)
      "#{@namespace}:coordination:#{str}"
    end

    class LockData
      DEFAULT_TTL = 3600

      def initialize(redlock, lock_info, lock_name)
        @redlock = redlock
        @lock_info = lock_info
        @lock_name = lock_name
        @lock_data_key = "#{lock_name}:data"
      end

      def info
        @lock_info
      end

      def valid?
        @redlock.valid_lock?(@lock_info)
      end

      def valid!
        return true if valid?

        raise ::Unity::Coordination::WriteError.new(@lock_name)
      end

      def keys
        Unity::Utils::RedisService.instance.hkeys(@lock_data_key)
      end

      def to_h
        Unity::Utils::RedisService.instance.hgetall(@lock_data_key)
      end

      def key?(key)
        Unity::Utils::RedisService.instance.hexists(@lock_data_key, key.to_s)
      end

      def [](key)
        Unity::Utils::RedisService.instance.hget(@lock_data_key, key.to_s)
      end

      def []=(key, value)
        if !value.nil?
          write(key, value)
        else
          delete(key)
        end
      end

      def set(key, value, ttl: DEFAULT_TTL, nx: false)
        valid! # check lock validity

        Unity::Utils::RedisService.instance.transaction do |redis|
          if nx == true
            redis.hsetnx(@lock_data_key, key.to_s, value.to_s)
          else
            redis.hset(@lock_data_key, key.to_s, value.to_s)
          end
          redis.expire(@lock_data_key, ttl)
        end
      end

      def delete(key)
        valid! # check lock validity

        Unity::Utils::RedisService.instance.hdel(@lock_data_key, key.to_s)
      end

      def ttl
        Unity::Utils::RedisService.instance.ttl(@lock_data_key)
      end

      def incr(key, number = 1)
        valid! # check lock validity

        Unity::Utils::RedisService.instance.transaction do |redis|
          redis.hincrby(@lock_data_key, key.to_s, number)
          redis.expire(@lock_data_key, ttl)
        end
      end

      def touch!(ttl: DEFAULT_DATA_TTL)
        Unity::Utils::RedisService.instance.expire(@lock_data_key, ttl)
      end
    end
  end
end
