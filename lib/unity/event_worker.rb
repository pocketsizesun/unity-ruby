# frozen_string_literal: true

module Unity
  class EventWorker
    include Shoryuken::Worker

    shoryuken_options auto_delete: true

    def self.queue=(arg)
      shoryuken_options(queue: arg.to_s)
    end

    def perform(_sqs_msg, body)
      Unity.logger&.debug "process event: #{body}"
      event = Unity::Event.parse(body)
      event_handler = Unity.application.find_event_handler(event.name)
      if event_handler.nil?
        Unity.logger&.error(
          'message' => "unable to find event handler for '#{event.name}'",
          'event' => event
        )
        return
      end
      event_handler.call(event)
      true
    end
  end
end
