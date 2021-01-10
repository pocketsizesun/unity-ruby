# frozen_string_literal: true

module Unity
  module Coordination
    class Lock
      DEFAULT_TTL = 10
      TABLE_NAME = 'unity-locks'
      LOCK_EXPR_ATTRIBUTE_NAMES = { '#ttl' => 'ttl' }.freeze
      REFRESH_EXPR_ATTRIBUTE_NAMES = { '#ttl' => 'ttl' }.freeze

      Error = Class.new(StandardError) do
        attr_reader :lock

        def initialize(lock)
          @lock = lock
        end
      end
      LockError = Class.new(Error)
      RefreshError = Class.new(Error)

      def self.table_name
        @table_name ||= TABLE_NAME
      end

      def self.table_name=(arg)
        @table_name = arg.to_s
      end

      def self.with_lock(name, **kwargs, &block)
        new(name, **kwargs).with_lock(&block)
      end

      def initialize(name, **kwargs)
        @name = name
        @ttl = (kwargs[:ttl] || DEFAULT_TTL).to_i
        @owner = kwargs[:owner] || Socket.gethostname
        @table_name = kwargs[:table_name] || self.class.table_name
      end

      def lock(ttl: nil)
        now = current_time
        Unity::Utils::DynamoService.instance.put_item(
          table_name: @table_name,
          item: {
            'n' => @name,
            'l_owner' => @owner,
            'ttl' => now + (ttl || @ttl)
          },
          condition_expression: 'attribute_not_exists(#ttl) OR #ttl < :ttl',
          expression_attribute_names: LOCK_EXPR_ATTRIBUTE_NAMES,
          expression_attribute_values: { ':ttl' => now }
        )
        true
      rescue Aws::DynamoDB::Errors::ConditionalCheckFailedException
        false
      end

      def lock!(**kwargs)
        return true if lock(**kwargs)

        raise LockError, self
      end

      def release
        Unity::Utils::DynamoService.instance.delete_item(
          table_name: @table_name,
          key: { 'n' => @name },
          condition_expression: 'l_owner = :owner',
          expression_attribute_values: { ':owner' => @owner }
        )
        true
      rescue Aws::DynamoDB::Errors::ConditionalCheckFailedException => e
        false
      end

      def refresh!(extend_time = 10)
        now = current_time
        Unity::Utils::DynamoService.instance.update_item(
          table_name: self.class.table_name,
          key: { 'n' => @name },
          update_expression: 'SET #ttl = :ttl',
          condition_expression: 'attribute_exists(#ttl) AND #ttl > :now AND l_owner = :owner',
          expression_attribute_names: LOCK_EXPR_ATTRIBUTE_NAMES,
          expression_attribute_values: {
            ':ttl' => now + extend_time,
            ':owner' => @owner,
            ':now' => now
          }
        )
        true
      rescue Aws::DynamoDB::Errors::ConditionalCheckFailedException
        raise RefreshError, self
      end

      def with_lock(ttl: DEFAULT_TTL, max_retries: 3, retry_interval: 1)
        retry_count = 0
        begin
          lock!(ttl: ttl)
          yield(self)
          release
        rescue LockError => e
          if retry_count < max_retries
            retry_count += 1
            sleep retry_interval
            retry
          end
          raise e
        end
      end

      private

      def current_time
        Process.clock_gettime(Process::CLOCK_REALTIME, :second)
      end
    end
  end
end
