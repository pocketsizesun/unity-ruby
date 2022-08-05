# frozen_string_literal: true

module Unity
  class EventEmitter
    def initialize(source, event_bus_name, **kwargs)
      @source = source
      @event_bus_name = event_bus_name
      @eventbridge = kwargs[:event_bridge_client] || Aws::EventBridge::Client.new
    end

    def parse(item)
      Unity::Event.new(
        id: item['id'],
        type: item['detail-type'],
        date: Time.parse(item['time']),
        data: item['detail']
      )
    end

    def publish(type, data, date = Time.now)
      result = @eventbridge.put_events(
        entries: [
          {
            event_bus_name: @event_bus_name,
            time: date,
            source: @source,
            detail_type: type,
            detail: data.to_json
          }
        ]
      )
      return true if result.failed_entry_count == 0

      raise Error, result
    end

    # @param events [Array<Unity::Event>] An array of {Unity::Event}
    def put(*events)
      result = @eventbridge.put_events(
        entries: events.map do |event|
          {
            event_bus_name: @event_bus_name,
            time: event.date,
            source: @source,
            detail_type: event.type,
            detail: event.data.to_json
          }
        end
      )
      return true if result.failed_entry_count == 0

      raise Error, result
    end

    class Error < StandardError
      def initialize(result)
        @result = result
        messages = result[:entries].collect.with_index do |entry, idx|
          "[event #{idx}] #{entry.error_message}"
        end
        super(messages.join(', '))
      end
    end
  end
end
