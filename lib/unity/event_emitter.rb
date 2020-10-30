# frozen_string_literal: true

module Unity
  # This is an example of documentation comment
  class EventEmitter
    def initialize(source_name, topic_arn: nil, connection_pool_size: 4, connection_pool_timeout: 5, client: nil)
      @source_name = source_name.to_s
      @topic_arn = topic_arn || ENV.fetch('TIKT_EVENTS_TOPIC')
      @connection_pool = ConnectionPool.new(
        size: connection_pool_size.to_i,
        timeout: connection_pool_timeout.to_i
      ) { client || Aws::SNS::Client.new }
    end

    def emit(type, data = nil)
      event = Event.new(type: type, data: data)
      @connection_pool.with do |conn|
        conn.publish(
          topic_arn: @topic_arn,
          message: event.to_json,
          message_attributes: {
            source_urn: {
              data_type: 'String',
              string_value: "urn:events:source/#{@source_name}"
            },
            event_type: { data_type: 'String', string_value: type }
          }
        )
      end
      event
    end
  end
end
