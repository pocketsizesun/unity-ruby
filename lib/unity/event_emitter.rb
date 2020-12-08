# frozen_string_literal: true

module Unity
  # This is an example of documentation comment
  class EventEmitter
    attr_reader :source

    def initialize(source, topic_arn: nil, connection_pool_size: 4, connection_pool_timeout: 5, client: nil)
      @source = source.to_s
      @topic_arn = topic_arn || ENV.fetch('UNITY_EVENT_STREAM_TOPIC_URN')
      @connection_pool = ConnectionPool.new(
        size: connection_pool_size.to_i,
        timeout: connection_pool_timeout.to_i
      ) { client || Aws::SNS::Client.new }
    end

    def emit(type, data = {})
      Unity::Event.new(name: "#{source}:#{type}", data: data).tap do |event|
        @connection_pool.with do |conn|
          conn.publish(
            topic_arn: @topic_arn,
            message: event.to_json,
            message_attributes: {
              event_source_urn: {
                data_type: 'String',
                string_value: "urn:eventstream:source/#{@source}"
              },
              event_name: { data_type: 'String', string_value: event.name },
              event_namespace: { data_type: 'String', string_value: event.namespace },
              event_type: { data_type: 'String', string_value: event.type }
            }
          )
        end
      end
    end
  end
end
