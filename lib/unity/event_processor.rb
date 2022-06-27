# frozen_string_literal: true

module Unity
  class EventProcessor
    def self.registered_events
      @registered_events ||= {}
    end

    def self.on(name, klass = nil, &block)
      registered_events[name] ||= []
      registered_events << klass || block
    end

    def initialize(debug_mode: false)
      @debug_mode = debug_mode
    end

    # process an Unity parsed event
    # Example:
    # processor = Unity::EventProcessor.new
    # event = Unity::Event.parse(body)
    # processor.call(event)
    # @param event [Unity::Event] An Unity event object
    # @return [Boolean]
    def call(event)
      Unity.logger&.debug("incoming event: #{event.to_json}") if @debug_mode == true

      # retrieve all event handlers
      event_handlers = self.class.registered_events[event.name]

      # check if there is no event handlers associated to that event
      if event_handlers.nil?
        Unity.logger&.warn(
          'message' => "there is no event handlers for '#{event.name}'",
          'event' => event
        )
        return
      end

      # execute event handlers
      event_handlers.each do |event_handler|
        event_handler.call(event)
      end

      # delete SQS message
      sqs_msg.delete

      true
    rescue Exception => e
      Unity.logger&.fatal(
        'error' => e.message,
        'exception_klass' => e.class.to_s,
        'exception_backtrace' => e.backtrace,
        'event_body' => body
      )

      raise e
    end
  end
end
