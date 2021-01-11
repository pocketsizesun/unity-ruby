# frozen_string_literal: true

require 'aws-sdk-dynamodbstreams'
require 'aws-sdk-dynamodbstreams-event-parser'

module Unity
  class DynamoDBStreamWorker
    include Shoryuken::Worker

    shoryuken_options auto_delete: true

    HOOK_TYPES = {
      'INSERT' => :insert,
      'REMOVE' => :remove,
      'MODIFY' => :update
    }.freeze

    def self.configure(&block)
      instance_exec(&block)
    end

    def self.event_parser
      @event_parser ||= Aws::DynamoDBStreams::EventParser.new
    end

    def self.queue(arg)
      shoryuken_options(queue: arg.to_s)
    end

    def self.table_handlers
      @table_handlers ||= {}
    end

    def self.table(name, &block)
      table_handlers[name] = TableHandler.new(&block)
    end

    def perform(_sqs_msg, body)
      Unity.logger&.debug(
        'message' => "process dynamodb stream record '#{self.class}'",
        'body' => body
      )
      event = self.class.event_parser.parse(body)
      process_event(event)
    rescue Exception => e
      Unity.logger&.fatal(
        'error' => e.message,
        'exception_klass' => e.class.to_s,
        'exception_backtrace' => e.backtrace,
        'event_body' => body
      )
      raise e
    end

    def process_event(event)
      event_source_arn_split = event.event_source_arn.split(':', 6)
      table_name = event_source_arn_split[5].split('/').at(1)
      unless self.class.table_handlers.key?(table_name)
        Unity.logger&.debug "no table handler for '#{table_name}'"
        return
      end

      hook_type = HOOK_TYPES[event.event_name]
      return if hook_type.nil?

      self.class.table_handlers[table_name].run(hook_type, event)
    end

    class TableHandler
      def initialize(&block)
        @handlers = { insert: [], remove: [], update: [] }
        instance_exec(&block)
      end

      def on(type, handler = nil, &block)
        @handlers[type] ||= []
        @handlers[type] << handler || block
      end

      def on_insert(handler = nil, &block)
        on(:insert, handler || block)
      end

      def on_remove(handler = nil, &block)
        on(:remove, handler || block)
      end

      def on_update(handler = nil, &block)
        on(:update, handler || block)
      end

      def run(type, event)
        return if @handlers[type].nil?

        @handlers[type].each do |handler|
          handler.call(event)
        end
      end
    end
  end
end
