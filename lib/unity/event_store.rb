# frozen_string_literal: true

module Unity
  class EventStore
    PUBLISH_EXPR_ATTRIBUTE_NAMES = { '#date' => 'date', '#id' => 'id' }.freeze

    Error = Class.new(StandardError)

    EventDuplicatedError = Class.new(Error) do
      attr_reader :event

      def initialize(event)
        super("event duplicated: #{event.id}")
        @event = event
      end
    end

    def initialize(config = {})
      @table_name = config.fetch(
        :table_name, Unity.application.config.event_store_table
      )
    end

    def create(event)
      Unity::Utils::DynamoService.instance.put_item(
        table_name: TimeQueue::Event::TABLE_NAME,
        condition_expression: 'attribute_not_exists(#date) AND attribute_not_exists(#id)',
        expression_attribute_names: PUBLISH_EXPR_ATTRIBUTE_NAMES,
        item: event.as_dynamo_item
      )
      true
    rescue Aws::DynamoDB::Errors::ConditionalCheckFailedException
      raise EventDuplicatedError, event
    end

    def publish(name, data = {}, date = Time.now)
      Unity::Event.new(date: date, name: name, data: data).tap do |event|
        create(event)
      end
    end
  end
end
