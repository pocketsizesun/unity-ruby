# frozen_string_literal: true

module Unity
  module Coordination
    class Information
      DEFAULT_TTL = 10
      TABLE_NAME = 'unity-informations'
      Record = Struct.new(:name, :value, :written_by, :written_at, :ttl)

      def self.table_name
        @table_name ||= TABLE_NAME
      end

      def self.table_name=(arg)
        @table_name = arg.to_s
      end

      def self.write(name, value, **kwargs)
        new(**kwargs).write(name, value, ttl: kwargs[:ttl])
      end

      def self.batch_write(data, **kwargs)
        new(**kwargs).batch_write(data, ttl: kwargs[:ttl])
      end

      def self.delete(name, **kwargs)
        new(**kwargs).delete(name)
      end

      def initialize(writer = Socket.gethostname, **kwargs)
        @writer = writer
        @table_name = kwargs[:table_name] || self.class.table_name
      end

      def get(name)
        result = Unity::Utils::DynamoService.instance.get_item(
          table_name: @table_name,
          key: { 'n' => name }
        )
        return if result.item.nil?

        Record.new(
          result.item['n'], result.item['v'],
          result.item['w_by'],
          Time.at(result.item['w_at'].to_i),
          result.item['ttl'] - result.item['w_at']
        )
      end

      def delete(name)
        Unity::Utils::DynamoService.instance.delete_item(
          table_name: @table_name,
          condition_expression: 'attribute_exists(n)',
          key: { 'n' => name }
        )
        true
      rescue Aws::DynamoDB::Errors::ConditionalCheckFailedException
        false
      end

      def write(name, value, ttl: nil)
        Record.new(name, value, @writer, current_time, ttl).tap do |record|
          Unity::Utils::DynamoService.instance.put_item(
            table_name: @table_name,
            item: record_to_item(record)
          )
        end
      end

      def batch_write(data, ttl: nil)
        now = current_time
        request_items = []
        records = []
        data.each do |key, value|
          record = Record.new(key, value, @writer, now, ttl)
          records << record
          request_items.push(
            { put_request: { item: record_to_item(record) } }
          )
        end

        Unity::Utils::DynamoService.instance.batch_write_item(
          request_items: { @table_name => request_items }
        )

        records
      end

      private

      def current_time
        Process.clock_gettime(Process::CLOCK_REALTIME, :second)
      end

      def record_to_item(record)
        {
          'n' => record.name,
          'v' => record.value,
          'w_by' => record.written_by,
          'w_at' => record.written_at,
          'ttl' => !record.ttl.nil? ? record.written_at + record.ttl.to_i : nil
        }
      end
    end
  end
end
