# frozen_string_literal: true

module Unity
  class Coordination
    DEFAULT_TTL = 86_400
    DEFAULT_LOCK_TTL = 60
    LOCK_EXPR_ATTRIBUTE_NAMES = { '#ttl' => 'ttl' }.freeze
    WRITE_EXPR_ATTRIBUTE_NAMES = { '#data' => 'data', '#ttl' => 'ttl' }.freeze
    REFRESH_EXPR_ATTRIBUTE_NAMES = { '#ttl' => 'ttl' }.freeze

    RELEASE_UPDATE_EXPR = <<~EXPR
      REMOVE l_until, l_owner
    EXPR

    Error = Class.new(StandardError) do
      attr_reader :lock

      def initialize(lock)
        @lock = lock
      end
    end
    LockError = Class.new(Error)
    RefreshError = Class.new(Error)

    Row = Struct.new(:name, :data, :ttl)

    def self.table_name
      @table_name ||= Unity.application.config.coordination_table
    end

    def self.table_name=(arg)
      @table_name = arg.to_s
    end

    def initialize(owner = Socket.gethostname)
      @owner = owner
    end

    def lock(name, **kwargs)
      now = current_time
      row = Row.new(name, nil, nil)
      result = Unity::Utils::DynamoService.instance.update_item(
        table_name: self.class.table_name,
        key: { 'n' => row.name },
        condition_expression: '(attribute_not_exists(l_until) OR l_until < :l_until) OR (l_owner = :l_owner)',
        expression_attribute_names: LOCK_EXPR_ATTRIBUTE_NAMES,
        expression_attribute_values: {
          ':l_until' => now + (kwargs[:ttl] || DEFAULT_LOCK_TTL),
          ':l_owner' => @owner
        },
        update_expression: 'SET l_owner = :l_owner, l_until = :l_until, #ttl = if_not_exists(#ttl, :l_until)',
        return_values: 'ALL_NEW'
      )
      row.data = result.attributes['data']
      row.ttl = Time.at(result.attributes['ttl'].to_i)
      row
    rescue Aws::DynamoDB::Errors::ConditionalCheckFailedException
      nil
    end

    def write(name, data, **kwargs)
      now = current_time
      Unity::Utils::DynamoService.instance.update_item(
        table_name: self.class.table_name,
        key: { 'n' => name },
        update_expression: 'SET #data = :data, #ttl = :ttl',
        condition_expression: 'attribute_exists(l_until) AND l_until > :now AND l_owner = :l_owner',
        expression_attribute_names: WRITE_EXPR_ATTRIBUTE_NAMES,
        expression_attribute_values: {
          ':l_owner' => @owner,
          ':now' => now,
          ':ttl' => now + (kwargs[:ttl] || DEFAULT_TTL),
          ':data' => data
        }
      )
    end

    def lock!(name, **kwargs)
      row = lock(name, **kwargs)
      return row unless row.nil?

      raise LockError, self
    end

    def release(name)
      now = current_time
      Unity::Utils::DynamoService.instance.update_item(
        table_name: self.class.table_name,
        key: { 'n' => name },
        update_expression: RELEASE_UPDATE_EXPR,
        condition_expression: 'attribute_exists(l_until) AND l_until >= :now AND l_owner = :l_owner',
        expression_attribute_values: { ':l_owner' => @owner, ':now' => now }
      )
      true
    rescue Aws::DynamoDB::Errors::ConditionalCheckFailedException
      false
    end

    def refresh!(name, extend_time = 10)
      now = current_time
      Unity::Utils::DynamoService.instance.update_item(
        table_name: self.class.table_name,
        key: { 'n' => name },
        update_expression: 'SET l_until = :l_until',
        condition_expression: 'attribute_exists(l_until) AND l_until > :now AND l_owner = :l_owner',
        expression_attribute_names: LOCK_EXPR_ATTRIBUTE_NAMES,
        expression_attribute_values: {
          ':l_until' => now + extend_time,
          ':l_owner' => @owner,
          ':now' => now
        }
      )
      true
    rescue Aws::DynamoDB::Errors::ConditionalCheckFailedException
      raise RefreshError, self
    end

    def with_lock(name, ttl: DEFAULT_LOCK_TTL, max_retries: 3, retry_interval: 1)
      retry_count = 0
      begin
        row = lock!(name, ttl: ttl)
        yield(row)
        release(name)
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
